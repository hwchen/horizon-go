module horizon;

import std::core::mem;
import std::io;
import sgf;

fn void! main() {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd];B[ad];W[bd])(;B[hh];W[hg]))";

	DynamicArenaAllocator arena;
	arena.init(1024, allocator::heap());
	for (int i = 0; i < 10; i += 1) {
		GameTree gt = sgf::parse_sgf(input, &arena)!;
		defer arena.free();
	}
}
