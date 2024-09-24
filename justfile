build *args="":
    c3c compile {{args}} main.c3 sgf.c3

test-sgf:
    c3c compile-test sgf.c3

valgrind:
    just build && valgrind --track-origins=yes --leak-check=full --leak-resolution=high ./horizon
