module rtc_clock_formal;
  (* anyseq *) wire clk_i;
  (* anyseq *) wire rstn_i;

  (* anyseq *) wire        clock_update_i;
  wire [21:0] clock_o;
  (* anyseq *) wire [21:0] clock_i;
  (* anyseq *) wire  [9:0] init_sec_cnt_i;

  (* anyseq *) wire        timer_update_i;
  (* anyseq *) wire        timer_enable_i;
  (* anyseq *) wire        timer_retrig_i;
  (* anyseq *) wire [16:0] timer_target_i;
  wire [16:0] timer_value_o;

  (* anyseq *) wire        alarm_enable_i;
  (* anyseq *) wire        alarm_update_i;
  (* anyseq *) wire [21:0] alarm_clock_i;
  wire [21:0] alarm_clock_o;

  wire event_o;
  wire update_day_o;

  rtc_clock dut (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clock_update_i(clock_update_i),
    .clock_o(clock_o),
    .clock_i(clock_i),
    .init_sec_cnt_i(init_sec_cnt_i),
    .timer_update_i(timer_update_i),
    .timer_enable_i(timer_enable_i),
    .timer_retrig_i(timer_retrig_i),
    .timer_target_i(timer_target_i),
    .timer_value_o(timer_value_o),
    .alarm_enable_i(alarm_enable_i),
    .alarm_update_i(alarm_update_i),
    .alarm_clock_i(alarm_clock_i),
    .alarm_clock_o(alarm_clock_o),
    .event_o(event_o),
    .update_day_o(update_day_o)
  );

  // Property inspired by HACKDAC_p15 in hackatdac18/properties.tcl.
  always @(posedge clk_i) begin
    if (rstn_i) begin
      assert(dut.r_seconds < 8'h59);
    end
  end
endmodule
