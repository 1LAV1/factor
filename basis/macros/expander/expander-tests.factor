IN: macros.expander.tests
USING: macros.expander tools.test math combinators.short-circuit
kernel ;

[ t ] [ 20 [ { [ integer? ] [ even? ] [ 10 > ] } 1&& ] expand-macros call ] unit-test

[ f ] [ 15 [ { [ integer? ] [ even? ] [ 10 > ] } 1&& ] expand-macros call ] unit-test

[ f ] [ 5.0 [ { [ integer? ] [ even? ] [ 10 > ] } 1&& ] expand-macros call ] unit-test
