module sgf;

import std::collections::list;
import std::core::array;
import std::core::mem::allocator;
import std::core::mem;

def Props = List(<Prop>);
def Nodes = List(<Node*>);

struct Game {
	Props props;
	Nodes children;
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

fn Game! parse_sgf(String input, Allocator alloc) {
	Parser p;
	Game game;
	Nodes children;
	children.new_init();
	Props game_props;
	game_props.new_init();
	game.children = children;
	game.props = game_props;

	// parse root metadata
	p.expect("(;")!;
	if (p.peek()! != ';' || p.peek()! != '(' || p.peek()! != ')') {
		Prop prop = p.prop(alloc)!;
		game.props.push(prop);
	}

	// parse root children
	// stack tracks scopes; A node is put on here if it's the parent of a new scope
	Nodes stack;
	stack.temp_init();
	Node* parent;
	@pool() { // TODO can I use defer/free the stack?
		while(true) {
			if (p.match("(")) {
				stack.push(parent);
			}
			if (p.match(")")) {
				stack.pop()!;
				Node*! last = stack.last();
				if (catch last) break;
				parent = last;
			}
			if (!p.match(";")) break;

			Props props;
			props.new_init();
			if (p.peek()! != ';' || p.peek()! != '(' || p.peek()! != ')') {
				Prop prop = p.prop(alloc)!;
				props.push(prop);
			}

			Node* node = mem::new(Node, { .props = props });
			if (parent == null) {
				game.children.push(node);
			} else {
				parent.children.push(node);
			}
			parent = node;

			if (stack.len() == 0 && p.peek()! == ')') break;
		}
	};
	p.expect(")")!;

	return { .children = children };
}

struct Parser {
	int curr;
	char[] src;
}

fn bool Parser.match(&p, String s) {
	if (s == p.src[p.curr:s.len]) {
		p.curr += 1;
		return true;
	} else {
		return false;
	}

}
fn void! Parser.expect(&p, String s) {
	if (s == p.src[p.curr:s.len]) {
		p.curr += 1;
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
		.label = ((String)p.src[p.curr:split_idx]).copy(),
		.data = ((String)p.src[split_idx + 1:end_idx]).copy(),
	};
	return prop;
}

fault ParseError {
	UNEXPECTED,
	EXPECTED_PROP,
}

fn void! test_no_variation() @test {
	String input = "(;FF[4]GM[1]SZ[19];B[aa];W[bb];B[cc];W[dd];B[ad];W[bd])";
	parse_sgf(input, allocator::heap())!;
}
