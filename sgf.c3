// TODO test more variations
// TODO parse out move position from props
// TODO skip whitespace (do I care?)
// TODO escape strings
module sgf;

import std::collections::list;
import std::core::array;
import std::core::mem::allocator;
import std::core::mem;
import std::io;

def Props = List(<Prop>);
def Nodes = List(<Node*>);

// Tree of games. One tree can hold multiple games.
struct GameTree {
	Node* root;
}

struct Node {
	Props props;
	Nodes children;
}

struct Prop {
	String label;
	String data;
}

enum Player {
	BLACK,
	WHITE,
}

// instead of pool, just define a temp arena? Behavior is not clear,
// especially if there's nested pools (a temp alloc gets passed in)
fn GameTree! parse_sgf(String src, Allocator alloc) {
	Parser p = { .src = src };

	@pool(alloc) {
		// stack tracks scopes; A node is put on here
		// if it's the parent of a new scope
		Nodes stack;
		stack.temp_init();
		Node* parent;

		while(true) {
			if (p.match("(")) {
				stack.push(parent);
			}
			if (p.match(")")) {
				Node* n = stack.pop()!;
				if (stack.len() == 0) {
					return { .root = n };
				} else {
					parent = n;
				}
			}
			p.match(";");

			Props props;
			props.new_init(allocator:alloc);
			while (p.peek()! != ';' && p.peek()! != '(' && p.peek()! != ')') {
				Prop prop = p.prop(alloc)!;
				props.push(prop);
			}

			Node* node = allocator::new(alloc, Node, { .props = props });
			node.children.new_init(allocator:alloc);
			if (parent == null) {
				// first time through, need to set root
				stack[0] = node;
			} else {
				parent.children.push(node);
			}
			parent = node;
			//io::printfn("stack_len: %d, Rest: %s", stack.len(), p.src[p.curr..]);
		}
	};
}

struct Parser {
	usz curr;
	char[] src;
}

fn bool Parser.match(&p, String s) {
	if (p.curr + s.len > p.src.len) {
		return false;
	}
	if (s == p.src[p.curr:s.len]) {
		p.curr += 1;
		return true;
	} else {
		return false;
	}

}
fn void! Parser.expect(&p, String s) {
	if (s == p.src[p.curr:s.len]) {
		p.curr += s.len;
	} else {
		return ParseError.UNEXPECTED?;
	}
}
fn char! Parser.peek(&p) {
	return p.src[p.curr];
}
fn Prop! Parser.prop(&p, Allocator alloc) {
	usz! split_idx = array::index_of(p.src[p.curr..], '[');
	usz! end_idx = array::index_of(p.src[p.curr..], ']');
	if (catch split_idx) {
		return ParseError.EXPECTED_PROP?;
	}
	if (catch end_idx) {
		return ParseError.EXPECTED_PROP?;
	}
	Prop prop = {
		.label = ((String)p.src[p.curr: split_idx]).copy(allocator:alloc),
		.data = ((String)p.src[p.curr + split_idx + 1:end_idx - split_idx - 1]).copy(allocator:alloc),
	};
	//io::printfn("Prop: %s, %s", prop.label, prop.data);
	p.curr += end_idx + 1;
	return prop;
}

fault ParseError {
	UNEXPECTED,
	EXPECTED_PROP,
}

fn void! test_empty() @test {
	String input = "(;)";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has no children
	assert(gt.root.children.len() == 0);
	assert(gt.root.props.len() == 0);
}

fn void! test_root_only() @test {
	String input = "(;FF[4])";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has no children
	assert(gt.root.children.len() == 0);
}

fn void! test_nested_temp_allocators() @test {
	// there's a pool here, and another pool in parse_sgf
	String input = "(;FF[4])";
	@pool() {
		GameTree gt = parse_sgf(input, allocator::temp())!;
		// root has no children
		assert(gt.root.children.len() == 0);
	};
}

fn void! test_one_move() @test {
	String input = "(;FF[4];B[aa])";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has one child
	assert(gt.root.children.len() == 1);
}

fn void! test_no_variation() @test {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb];B[cc];W[dd];B[ad];W[bd])";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has only one child
	assert(gt.root.children.len() == 1);
	// first move node has only one child
	Node* node = gt.root.children[0];
	assert(node.children.len() == 1);
	// next five nodes have only one child
	for (int i; i < 4; i += 1) {
		node = node.children[0];
		assert(node.children.len() == 1);
	}
	// last node has no child
	node = node.children[0];
	assert(node.children.len() == 0);
	// TODO refactor, there's got to be a cleaner way to test
}

fn void! test_one_variation() @test {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd];B[ad];W[bd])(;B[hh];W[hg]))";
	GameTree gt = parse_sgf(input, allocator::heap())!;
	// root has only one child
	assert(gt.root.children.len() == 1);
	// first move node has only one child
	Node* node = gt.root.children[0];
	assert(node.children.len() == 1);
	// second move node has two children
	node = node.children[0];
	assert(node.children.len() == 2);
}

// test two variations
// test nested variations
