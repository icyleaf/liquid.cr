require "./context"

module Liquid::Nodes
  abstract class Node
    getter children
    @children = Array(Node).new

    abstract def initialize(token)

    abstract def render(data, io)

    def <<(node : Node)
      @children << node
    end

    def_equals @children
  end

  class Root < Node
    def initialize
    end

    def initialize(token : Tokens::Token)
    end

    def render(data, io)
      @children.each &.render(data, io)
    end
  end

  class Unknow < Node
    def initialize(token : Tokens::Token)
    end

    def render(data, io)
    end
  end

  class BinOperator
    macro responds_to(l, o, r)
      if {{l.id}}.responds_to?(:{{o.id}})
        {{l.id}} {{o.id}} {{r.id}}
      else
        false
      end
    end

    EQ  = BinProc.new { |left, right| left == right }
    NE  = BinProc.new { |left, right| left != right }
    LE  = BinProc.new { |left, right| responds_to(left, :<=, right) }
    GE  = BinProc.new { |left, right| responds_to(left, :>=, right) }
    LT  = BinProc.new { |left, right| responds_to(left, :<, right) }
    GT  = BinProc.new { |left, right| responds_to(left, :>, right) }
    NOP = BinProc.new { false }

    @inner : BinProc

    def initialize(str : String)
      @inner = case str
               when "==" then EQ
               when "!=" then NE
               when "<=" then LE
               when ">=" then GE
               when "<"  then LT
               when ">"  then GT
               else
                 NOP
               end
    end

    def call(left : Context::DataType, right : Context::DataType)
      @inner.call left.as(Context::DataType), right.as(Context::DataType)
    end

    alias BinProc = Proc(Context::DataType, Context::DataType, Bool)
  end

  class Expression < Node
    VAR      = /\w+(\.\w+)*/
    OPERATOR = /==|!=|<=|>=|<|>/
    EXPR     = /^(?<left>#{VAR}) ?(?<op>#{OPERATOR}) ?(?<right>#{VAR})$/

    @var : String

    def initialize(token : Tokens::Expression)
      @var = token.content.strip
    end

    def initialize(var)
      @var = var.strip
    end

    def eval(data) : Context::DataType
      if @var == "true"
        true
      elsif @var == "false"
        false
      elsif @var.match /^#{VAR}$/
        data.get(@var)
      elsif m = @var.match EXPR
        op = BinOperator.new m["op"]
        le = Expression.new m["left"]
        re = Expression.new m["right"]
        op.call le.eval(data), re.eval(data)
      end
    end

    def render(data, io)
      io << eval(data)
    end
  end

  class Raw < Node
    @content : String

    def initialize(token : Tokens::Raw)
      @content = token.content
    end

    def render(data, io)
      io << @content
    end

    def_equals @children, @content
  end

  # Inside of a for-loop block, you can access some special variables:
  # Variable      	Description
  # loop.index 	    The current iteration of the loop. (1 indexed)
  # loop.index0   	The current iteration of the loop. (0 indexed)
  # loop.revindex 	The number of iterations from the end of the loop (1 indexed)
  # loop.revindex0 	The number of iterations from the end of the loop (0 indexed)
  # loop.first    	True if first iteration.
  # loop.last     	True if last iteration.
  # loop.length    	The number of items in the sequence.
  class For < Node
    GLOBAL = /for (?<var>\w+) in (?<range>.+)/
    RANGE  = /(?<start>[0-9]+)\.\.(?<end>[0-9]+)/

    @loop_var : String
    @begin : Int32 | Iterator(Context::DataType)
    @end : Int32 | Iterator(Context::DataType)

    def initialize(token : Tokens::ForStatement)
      @loop_var = ""
      @begin = @end = 0
      if gmatch = token.content.match GLOBAL
        @loop_var = gmatch["var"]
        if rmatch = gmatch["range"].match RANGE
          @begin = rmatch["start"].to_i
          @end = rmatch["end"].to_i
        end
      end
    end

    def render_with_range(data, io)
      data = Context.new data
      i = 0
      start = @begin.as(Int32)
      stop = @end.as(Int32)
      start.upto stop do |x|
        data.set(@loop_var, x)
        data.set("loop.index", i + 1)
        data.set("loop.index0", i)
        data.set("loop.revindex", stop - start - i + 1)
        data.set("loop.revindex0", stop - start - i)
        data.set("loop.first", x == start)
        data.set("loop.last", x == stop)
        data.set("loop.length", stop - start)
        children.each &.render(data, io)
        i += 1
      end
    end

    def render(data, io)
      if @begin.is_a?(Int32) && @end.is_a?(Int32)
        render_with_range data, io
      else
      end
    end
  end

  class If < Node
    SIMPLE_EXP = /if (?<left>.+) ?(?<operator>==|!=) ?(?<right>.+)/

    @elsif : Array(ElsIf)?
    @else : Else?

    def initialize(token : Tokens::IfStatement)
    end

    def render(data, io)
    end

    def add_elsif(token : Tokens::ElsIfStatement) : ElsIf
      @elsif ||= Array(ElsIf).new
      @elsif.not_nil! << ElsIf.new token
      @elsif.not_nil!.last
    end

    def set_else(token : Tokens::ElseStatement) : Else
      @else = Else.new token
    end

    def set_else(node : Else) : Else
      @else = node
    end

    def_equals @elsif, @else, @children
  end

  class Else < Node
    def initialize(token : Tokens::ElseStatement)
    end

    def render(data, io)
    end
  end

  class ElsIf < Node
    def initialize(token : Tokens::ElsIfStatement)
    end

    def render(data, io)
    end
  end
end