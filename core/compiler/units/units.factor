! Copyright (C) 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors kernel continuations assocs namespaces
sequences words vocabs definitions hashtables init sets
math.order classes.algebra ;
IN: compiler.units

SYMBOL: old-definitions
SYMBOL: new-definitions

TUPLE: redefine-error def ;

: redefine-error ( definition -- )
    \ redefine-error boa
    { { "Continue" t } } throw-restarts drop ;

: add-once ( key assoc -- )
    2dup key? [ over redefine-error ] when conjoin ;

: (remember-definition) ( definition loc assoc -- )
    >r over set-where r> add-once ;

: remember-definition ( definition loc -- )
    new-definitions get first (remember-definition) ;

: remember-class ( class loc -- )
    over new-definitions get first key? [ dup redefine-error ] when
    new-definitions get second (remember-definition) ;

: forward-reference? ( word -- ? )
    dup old-definitions get assoc-stack
    [ new-definitions get assoc-stack not ]
    [ drop f ] if ;

SYMBOL: recompile-hook

: <definitions> ( -- pair ) { H{ } H{ } } [ clone ] map ;

SYMBOL: definition-observers

GENERIC: definitions-changed ( assoc obj -- )

[ V{ } clone definition-observers set-global ]
"compiler.units" add-init-hook

: add-definition-observer ( obj -- )
    definition-observers get push ;

: remove-definition-observer ( obj -- )
    definition-observers get delete ;

: notify-definition-observers ( assoc -- )
    definition-observers get
    [ definitions-changed ] with each ;

: changed-vocabs ( assoc -- vocabs )
    [ drop word? ] assoc-filter
    [ drop vocabulary>> dup [ vocab ] when dup ] assoc-map ;

: updated-definitions ( -- assoc )
    H{ } clone
    dup forgotten-definitions get update
    dup new-definitions get first update
    dup new-definitions get second update
    dup changed-definitions get update
    dup dup changed-vocabs update ;

: compile ( words -- )
    recompile-hook get call
    dup [ drop crossref? ] assoc-contains?
    modify-code-heap ;

SYMBOL: outdated-tuples
SYMBOL: update-tuples-hook

: strongest-dependency ( how1 how2 -- how )
    [ called-dependency or ] bi@
    2dup [ method-dependency? ] both?
    [ [ class>> ] bi@ class-or <method-dependency> ] [ max ] if ;

: weakest-dependency ( how1 how2 -- how )
    [ inlined-dependency or ] bi@
    2dup [ method-dependency? ] both?
    [ [ class>> ] bi@ class-and <method-dependency> ] [ min ] if ;

: relevant-dependency? ( how to -- ? )
    #! Note that an intersection check alone is not enough,
    #! since we're also interested in empty mixins.
    2dup [ method-dependency? ] both? [
        [ class>> ] bi@
        [ classes-intersect? ] [ class<= ] 2bi or
    ] [ after=? ] if ;

: compiled-usage ( word -- assoc )
    compiled-crossref get at ;

: (compiled-usages) ( word dependency -- assoc )
    #! If the word is not flushable anymore, we have to recompile
    #! all words which flushable away a call (presumably when the
    #! word was still flushable). If the word is flushable, we
    #! don't have to recompile words that folded this away.
    [ drop compiled-usage ]
    [
        swap "flushable" word-prop inlined-dependency flushed-dependency ?
        weakest-dependency
    ] 2bi
    [ relevant-dependency? nip ] curry assoc-filter ;

: compiled-usages ( assoc -- seq )
    clone [
        dup [
            [ (compiled-usages) ] dip swap update
        ] curry assoc-each
    ] keep keys ;

: call-recompile-hook ( -- )
    changed-definitions get [ drop word? ] assoc-filter
    compiled-usages recompile-hook get call ;

: call-update-tuples-hook ( -- )
    update-tuples-hook get call ;

: unxref-forgotten-definitions ( -- )
    forgotten-definitions get
    keys [ word? ] filter
    [ delete-compiled-xref ] each ;

: finish-compilation-unit ( -- )
    call-recompile-hook
    call-update-tuples-hook
    unxref-forgotten-definitions
    dup [ drop crossref? ] assoc-contains? modify-code-heap ;

: with-nested-compilation-unit ( quot -- )
    [
        H{ } clone changed-definitions set
        H{ } clone outdated-tuples set
        [ finish-compilation-unit ] [ ] cleanup
    ] with-scope ; inline

: with-compilation-unit ( quot -- )
    [
        H{ } clone changed-definitions set
        H{ } clone forgotten-definitions set
        H{ } clone outdated-tuples set
        <definitions> new-definitions set
        <definitions> old-definitions set
        [
            finish-compilation-unit
            updated-definitions
            notify-definition-observers
        ] [ ] cleanup
    ] with-scope ; inline

: compile-call ( quot -- )
    [ define-temp ] with-compilation-unit execute ;

: default-recompile-hook ( words -- alist )
    [ f ] { } map>assoc ;

recompile-hook global
[ [ default-recompile-hook ] or ]
change-at
