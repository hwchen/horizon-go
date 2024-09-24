build *args="":
    c3c compile {{args}} main.c3 sgf.c3

test-sgf:
    c3c compile-test sgf.c3

valgrind:
    just build && valgrind --track-origins=yes --leak-check=full --leak-resolution=high ./horizon

# can inspect results with `perf report`
# sudo sysctl kernel.perf_event_paranoid=1
# sudo sysctl kernel.kptr_restrict=0
perf bin *args="":
    perf record --call-graph dwarf {{bin}} {{args}} > /dev/null

perf-horizon *args="":
    just build && just perf ./horizon {{args}}

# stackcollapse-perf.pl and flamegraph.pl symlinked into path from flamegraph repo
flamegraph:
    perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg
