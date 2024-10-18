
package Fixedpoint;
let max(x, y) = x > y? x : y;
`define DEF_REAL_TO_Q(name, i, f) \
    let name(x) = ((i)+(f))'(integer(x * (2**(f))));
`define DEF_Q_TO_REAL(name, i, f) \
    let name(x) = real'($signed(x)) / 2.0 ** (f);
`define DEF_FP_ADD(name, i0, f0, i1, f1, fr) \
    let name(x, y) = \
    ((f0) >= (f1)) ? \
        (   (  max((i0),(i1))+(f0))'(x) + \
            ( (max((i0),(i1))+(f0))'(y) <<< ((f0)-(f1)) ) \
        ) >>> ((f0)-(fr)) : \
        (   ( (max((i0),(i1))+(f1))'(x) <<< ((f1)-(f0)) ) + \
              (max((i0),(i1))+(f1))'(y) \
        ) >>> ((f1)-(fr));
`define DEF_FP_MUL(name, i0, f0, i1, f1, fr) \
    let name(x, y) = \
    (   ((i0)+(i1)+(f0)+(f1))'(x) * ((i0)+(i1)+(f0)+(f1))'(y) \
    ) >>> ((f0)+(f1)-(fr));
// // if you need DEF_FP_MUL and your compiler doesn't support "let":
// `define DEF_FP_MUL(name, i0, f0, i1, f1, fr) \
//     function automatic signed [(i0)+(i1)+(fr)-1:0] name(input signed [(i0)+(f0)-1:0] x, input signed [(i1)+(f1)-1:0] y); \
//         name = (((i0)+(i1)+(f0)+(f1))'(x) * ((i0)+(i1)+(f0)+(f1))'(y)) >>> ((f0)+(f1)-(fr)); \
//     endfunction
    
`define DEF_CPLX_CALC(typename, addname, subname, mulname, i, f) \
    typedef struct { \
        logic signed [(i)+(f)-1:0] re; \
        logic signed [(i)+(f)-1:0] im; \
    } typename; \
    function automatic typename mulname(typename a, typename b, logic sc); \
        mulname.re = ( (2*(i)+2*(f))'(a.re) * b.re - (2*(i)+2*(f))'(a.im) * b.im ) >>> ((f)+sc); \
        mulname.im = ( (2*(i)+2*(f))'(a.re) * b.im + (2*(i)+2*(f))'(a.im) * b.re ) >>> ((f)+sc); \
    endfunction \
    function automatic typename addname(typename a, typename b, logic sc); \
        addname.re = ( ((i)+(f)+1)'(a.re) + b.re ) >>> sc; \
        addname.im = ( ((i)+(f)+1)'(a.im) + b.im ) >>> sc; \
    endfunction \
    function automatic typename subname(typename a, typename b, logic sc); \
        subname.re = ( ((i)+(f)+1)'(a.re) - b.re ) >>> sc; \
        subname.im = ( ((i)+(f)+1)'(a.im) - b.im ) >>> sc; \
    endfunction
    
endpackage


module Pid #(
    parameter W = 32, FW = 16,
    parameter real P = 8, real I = 192, real D = 0,
    parameter real N = 100, real TS = 0.002,
    parameter real LIMIT = 10000
)(
    input wire clk, rst, en,
    input wire signed [W-1:0] in,
    output logic signed [W-1:0] out
);
    import Fixedpoint::*;
    wire signed [W-1:0] p = P * (2.0 ** FW);
    wire signed [W-1:0] i = (I * TS) * (2.0 ** FW);
    wire signed [W-1:0] d = D * (2.0 ** FW);
    wire signed [W-1:0] n = N * (2.0 ** FW);
    wire signed [W-1:0] ts = TS * (2.0 ** FW);
    wire signed [W-1:0] lim = LIMIT * (2.0 ** FW);
    `DEF_FP_MUL(mul, W-FW, FW, W-FW, FW, FW);
    wire signed [W-1:0] xp = mul(in, p);
    wire signed [W-1:0] xi = mul(in, i);
    logic signed [W-1:0] xi_acc;
    always_ff@(posedge clk) begin
        if(rst) xi_acc <= 1'sb0;
        else if(en) begin
            if(xi_acc + xi > lim) xi_acc <= lim;
            else if(xi_acc + xi < -lim) xi_acc <= -lim;
            else xi_acc <= xi_acc + xi;
        end
    end
    logic signed [W-1:0] dacc; 
    wire signed [W-1:0] xd  = mul(in, d);
    wire signed [W-1:0] xnd = mul((xd - dacc), n);   
    wire signed [W-1:0] tnd = mul(xnd, ts);
    always_ff@(posedge clk) begin
        if(rst) dacc <= 1'sb0;
        else if(en) begin
            if(dacc + tnd > lim) dacc = lim;
            else if(dacc + tnd < -lim) dacc = -lim;
            else dacc <= dacc + tnd;
        end
    end
    always_ff@(posedge clk) begin
        if(rst) out <= 1'sb0;
        else if(en) out <= xp + xi_acc + xnd;
    end
endmodule
