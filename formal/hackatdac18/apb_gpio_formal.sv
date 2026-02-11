module apb_gpio_formal;
  (* anyseq *) wire        HCLK;
  (* anyseq *) wire        HRESETn;
  (* anyseq *) wire        dft_cg_enable_i;
  (* anyseq *) wire [11:0] PADDR;
  (* anyseq *) wire [31:0] PWDATA;
  (* anyseq *) wire        PWRITE;
  (* anyseq *) wire        PSEL;
  (* anyseq *) wire        PENABLE;
  wire [31:0] PRDATA;
  wire PREADY;
  wire PSLVERR;
  (* anyseq *) wire [31:0] gpio_in;
  wire [31:0] gpio_in_sync;
  wire [31:0] gpio_out;
  wire [31:0] gpio_dir;
  wire [31:0][5:0] gpio_padcfg;
  wire interrupt;

  apb_gpio dut (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .dft_cg_enable_i(dft_cg_enable_i),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .PWRITE(PWRITE),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR),
    .gpio_in(gpio_in),
    .gpio_in_sync(gpio_in_sync),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir),
    .gpio_padcfg(gpio_padcfg),
    .interrupt(interrupt)
  );

  // Property inspired by HACKDAC_p4 in hackatdac18/properties.tcl.
  always @(posedge HCLK) begin
    if (HRESETn) begin
      assert(!((PWDATA == 32'h1234_5678) &&
               (dut.s_apb_addr == 5'b10010) &&
               (dut.r_gpio_lock == 32'h1234_5678)));
    end
  end
endmodule
