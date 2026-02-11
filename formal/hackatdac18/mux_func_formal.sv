module mux_func_formal;
  (* anyseq *) wire [127:0] a;
  (* anyseq *) wire [127:0] b;
  wire [127:0] c;
  (* anyseq *) wire [127:0] d;
  (* anyseq *) wire clk;
  (* anyseq *) wire rst;

  mux_func dut (
    .a(a),
    .b(b),
    .c(c),
    .d(d),
    .clk(clk),
    .rst(rst)
  );

  // Property inspired by HACKDAC_p21 in hackatdac18/properties.tcl.
  always @(posedge clk) begin
    assert(!(dut.c == dut.temperature_out));
  end
endmodule
