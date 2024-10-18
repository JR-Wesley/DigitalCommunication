
module ADPLL #(
    parameter PW=24, DW=12, AW=14
)(
    input wire clk, rst, en,
    input wire signed [DW-1:0] in,
    input wire signed [PW-1:0] base_freq,
    output logic signed [DW-1:0] sin, cos,
    output logic pilot
);
    logic signed [DW-1:0] mix, mix_fil;
    always_ff@(posedge clk) begin
        if(en) mix <= ((2*DW)'(in) * -sin) >>> (DW-1);
    end
    FIR #(DW, 27, '{    // low pass: 10\20 @100
     0.0009, 0.0039, 0.0096, 0.0157, 0.0165, 0.0063,-0.0153,-0.0382,
    -0.0430,-0.0115, 0.0601, 0.1533, 0.2328, 0.2641, 0.2328, 0.1533,
     0.0601,-0.0115,-0.0430,-0.0382,-0.0153, 0.0063, 0.0165, 0.0157,
     0.0096, 0.0039, 0.0009
    }) phaseDetFilter(clk, rst, en, mix, mix_fil);

    wire signed [PW-1:0] ph_err = PW'(mix_fil) <<< (PW-DW+1);

    localparam PIDW = (PW+4);
    logic signed [PIDW-1:0] freq_vari;
    Pid #(PIDW, PW-1, 0.021, 21000, 0, 1, 1e-8, 10)
        thePI( clk, rst, en, PIDW'(ph_err), freq_vari);
    logic signed [PW-1:0] freq;
    always_ff@(posedge clk) begin
        if(rst) freq <= base_freq;
        else if(en) freq <= PW'(freq_vari) + base_freq;
    end
    OrthDDS #(PW, DW, AW)
        theDds( clk, rst, en, freq, PW'(0), sin, cos );

endmodule
