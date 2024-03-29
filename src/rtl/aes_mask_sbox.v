//======================================================================
//
// aes_mask_sbox.v
// ---------------
// Sbox for the AES masking. The Sbox if from the PRINCE low latency
// block cipher, see:
//
// PRINCE – A Low-latency Block Cipher for Pervasive
// Computing Applications
// https://eprint.iacr.org/2012/529.pdf
//
//
// Author: Joachim Strombergson
// Copyright (c) 2019, Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

`default_nettype none

module aes_mask_sbox(
                     input wire [3 : 0]  x,
                     output wire [3 : 0] sx
                    );
  reg [3 : 0] tsx;
  assign sx = tsx;

  //----------------------------------------------------------------
  // sbox
  //----------------------------------------------------------------
  always @*
    begin : sbox
      case(x)
        4'h0 : tsx = 4'hb;
        4'h1 : tsx = 4'hf;
        4'h2 : tsx = 4'h3;
        4'h3 : tsx = 4'h2;
        4'h4 : tsx = 4'ha;
        4'h5 : tsx = 4'hc;
        4'h6 : tsx = 4'h9;
        4'h7 : tsx = 4'h1;
        4'h8 : tsx = 4'h6;
        4'h9 : tsx = 4'h7;
        4'ha : tsx = 4'h8;
        4'hb : tsx = 4'h0;
        4'hc : tsx = 4'he;
        4'hd : tsx = 4'h5;
        4'he : tsx = 4'hd;
        4'hf : tsx = 4'h4;
      endcase // case (x)
    end

endmodule // aes_mask_sbox

//======================================================================
// EOF aes_mask_sbox.v
//======================================================================
