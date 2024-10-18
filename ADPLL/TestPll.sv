
module TestQamCarRec;
    import SimSrcGen::*;
    logic clk, rst;
    initial GenClk(clk, 8000, 10000);
    initial GenRst(clk, rst, 2, 10);
    // ====== trans side ======
    logic bb_en;
    Counter #(4) cntBb(clk, rst, 1'b1, , bb_en);
    logic [3:0] cnt_dr;
    logic dr_en;     //  symbol rate : 2.5 Mbps
    localparam SRDIV = 10;
    Counter #(SRDIV) cntDr(clk, rst, bb_en, cnt_dr, dr_en);
    wire dr_en180 = bb_en & (cnt_dr == (SRDIV-1)/2);
    logic [7:0] lfsr_out;
    LFSR #(8, 9'h11d >> 1, 8'hff) lfsrDGen(
        clk, rst, dr_en, lfsr_out);
    logic [1:0] txi, txq;
    ManchesterEncoder
        manEncI0(clk, rst, dr_en, dr_en180, lfsr_out[0],, txi[0],),
        manEncI1(clk, rst, dr_en, dr_en180, lfsr_out[1],, txi[1],),
        manEncQ0(clk, rst, dr_en, dr_en180, lfsr_out[2],, txq[0],),
        manEncQ1(clk, rst, dr_en, dr_en180, lfsr_out[3],, txq[1],);
    logic signed [11:0] qam_if;
    logic [12:0] pp_ins_cnt;
    Counter #(8000) pilotInsCnt(clk, rst, 1'b1, pp_ins_cnt, );
    wire pilot_time = pp_ins_cnt inside {[13'd500:13'd1499]};
    QAMModulator #(12, 2)
        qamod(clk, rst, bb_en, 1'b1, ~pilot_time, txi, txq, qam_if);
    // ====== if channel ======
    logic signed [11:0] noi = '0, qam_if_noi;
    integer noi_seed = 8937872;
    always_comb begin
        noi = $dist_normal(noi_seed, 0, 10);
        qam_if_noi = qam_if + noi;
    end
    // ====== recv side ======
    logic signed [11:0] qam_if_fil;
    FIR #(12, 104, '{ // if band pass : 12/14 - 26\28M, @100Msps
    -0.0003, 0.0004,-0.0002, 0.0006, 0.0028, 0.0014,-0.0055,-0.0071,
     0.0034, 0.0119, 0.0036,-0.0089,-0.0070, 0.0017, 0.0009,-0.0012,
     0.0063, 0.0088,-0.0037,-0.0114,-0.0026, 0.0029,-0.0020, 0.0027,
     0.0142, 0.0055,-0.0148,-0.0126, 0.0030, 0.0010,-0.0028, 0.0150,
     0.0211,-0.0092,-0.0283,-0.0066, 0.0073,-0.0057, 0.0076, 0.0406,
     0.0161,-0.0449,-0.0396, 0.0096, 0.0016,-0.0116, 0.0678, 0.1075,
    -0.0556,-0.2208,-0.0774, 0.2155, 0.2155,-0.0774,-0.2208,-0.0556,
     0.1075, 0.0678,-0.0116, 0.0016, 0.0096,-0.0396,-0.0449, 0.0161,
     0.0406, 0.0076,-0.0057, 0.0073,-0.0066,-0.0283,-0.0092, 0.0211,
     0.0150,-0.0028, 0.0010, 0.0030,-0.0126,-0.0148, 0.0055, 0.0142,
     0.0027,-0.0020, 0.0029,-0.0026,-0.0114,-0.0037, 0.0088, 0.0063,
    -0.0012, 0.0009, 0.0017,-0.0070,-0.0089, 0.0036, 0.0119, 0.0034,
    -0.0071,-0.0055, 0.0014, 0.0028, 0.0006,-0.0002, 0.0004,-0.0003
    })  qamIfFilter(clk, rst, 1'b1, qam_if_noi, qam_if_fil);
    logic signed [11:0] lcsin_ref, lccos_ref;
//    OrthDDS #(32, 12, 14) locOrthDds(clk, rst, 1'b1,
//        32'sd858993459, 32'(int'(-0.9*2**32)), lcsin_ref, lccos_ref);
    OrthDDS #(24, 12, 14) locOrthDds(clk, rst, 1'b1,
        24'sd3355443, 24'(int'(-0.9*2**24)), lcsin_ref, lccos_ref);
    logic signed [11:0] loc_sin, loc_cos;
    logic pilot;
//    ADPLL #(32, 12, 14, 1000, 100) theCarrRecov(
//        clk, rst, 1'b1, qam_if_fil, 32'sd858900000, //freq err 100ppm
//        loc_sin, loc_cos, pilot);
    ADPLL #(24, 12, 14, 1000, 100) theCarrRecov(
        clk, rst, 1'b1, qam_if_fil, 24'sd3355000, //freq err 132ppm
        loc_sin, loc_cos, pilot);
    logic signed [11:0] ibb, qbb;
    QAMDemod #(12) qademod (clk, rst, 1'b1, bb_en,
        loc_sin, loc_cos, qam_if_fil, ibb, qbb);
    logic [1:0] rxi, rxq;
    logic sync;
    QAM16SyncJudge #(12, SRDIV/2, 10) qamSJ(
        clk, rst, bb_en, ibb, qbb, rxi, rxq, sync);
    logic [3:0] rxd, rxv;
    DiffManDecoder #(SRDIV)
        manDecI0(clk, rst, bb_en, rxi[0], rxd[0], rxv[0]),
        manDecI1(clk, rst, bb_en, rxi[1], rxd[1], rxv[1]),
        manDecQ0(clk, rst, bb_en, rxq[0], rxd[2], rxv[2]),
        manDecQ1(clk, rst, bb_en, rxq[1], rxd[3], rxv[3]);
endmodule
