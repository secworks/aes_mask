//======================================================================
//
// aes_mask_core.v
// ---------------
// Masking core for AES processing. Very experimental. Don't use
// before doing proper DPA analysis with the core and an a AES-core.
//
// Pull init() to initialize masking for a message., Pull next for
// each round in AES in the same cycle as SubBytes() and AddRoundKey().
// Pull finalize() to prepare for next block of the message.
//
// The result output is quite useless. But some tools really don't
// appreciate modules with only inputs.
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

module aes_mask_core(
                     input wire            clk,
                     input wire            reset_n,

                     input wire            init,
                     input wire            next,
                     input wire            finalize,

                     input wire [127 : 0]  key,
                     input wire            keylen,

                     input wire [127 : 0]  block,
                     output wire [127 : 0] result
                    );


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  // And wires to connect the sboxes.
  //----------------------------------------------------------------
  reg [127 : 0] round_key_reg;
  reg [127 : 0] round_key_new;
  reg           round_key_we;

  reg [127 : 0] state_reg;
  reg [127 : 0] state_new;
  reg           state_we;

  reg [127 : 0] sbox_in;
  wire [127 : 0] sbox_out;


  //----------------------------------------------------------------
  // Sbox Instantiations.
  //----------------------------------------------------------------
  genvar i;
  generate
    for(i = 0 ; i < 32 ; i = i + 1)
      begin: sboxes
        aes_mask_sbox sbox_array(.x(sbox_in[(((i + 1) * 4) - 1) : (i * 4)]),
                                 .sx(sbox_out[(((i + 1) * 4) - 1) : (i * 4)])
                                );
      end
  endgenerate


  //----------------------------------------------------------------
  // AES round functions with sub functions.
  //----------------------------------------------------------------
  function [7 : 0] gm2(input [7 : 0] op);
    begin
      gm2 = {op[6 : 0], 1'b0} ^ (8'h1b & {8{op[7]}});
    end
  endfunction // gm2

  function [7 : 0] gm3(input [7 : 0] op);
    begin
      gm3 = gm2(op) ^ op;
    end
  endfunction // gm3

  function [31 : 0] mixw(input [31 : 0] w);
    reg [7 : 0] b0, b1, b2, b3;
    reg [7 : 0] mb0, mb1, mb2, mb3;
    begin
      b0 = w[31 : 24];
      b1 = w[23 : 16];
      b2 = w[15 : 08];
      b3 = w[07 : 00];

      mb0 = gm2(b0) ^ gm3(b1) ^ b2      ^ b3;
      mb1 = b0      ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0      ^ b1      ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1      ^ b2      ^ gm2(b3);

      mixw = {mb0, mb1, mb2, mb3};
    end
  endfunction // mixw

  function [127 : 0] mixcolumns(input [127 : 0] data);
    reg [31 : 0] w0, w1, w2, w3;
    reg [31 : 0] ws0, ws1, ws2, ws3;
    begin
      w0 = data[127 : 096];
      w1 = data[095 : 064];
      w2 = data[063 : 032];
      w3 = data[031 : 000];

      ws0 = mixw(w0);
      ws1 = mixw(w1);
      ws2 = mixw(w2);
      ws3 = mixw(w3);

      mixcolumns = {ws0, ws1, ws2, ws3};
    end
  endfunction // mixcolumns


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign result = state_reg;


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin: reg_update
      if (!reset_n)
        begin
          round_key_reg <= 128'h0;
          state_reg     <= 128'h0;
        end
      else
        begin
          if (round_key_we)
            round_key_reg <= round_key_new;

          if (state_we)
            state_reg <= state_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // round_logic
  //
  // The actual round logic that causes the masking.
  //----------------------------------------------------------------
  always @*
    begin : round_logic
      reg [127 : 0] mixed_state;
      reg [127 : 0] rkey_state;

      state_new = 128'h0;
      state_we  = 1'h0;

      // AES Round. Almost.
      mixed_state = mixcolumns(state_reg);
      sbox_in = mixed_state;
      rkey_state = sbox_out ^ round_key_reg;

      if (init)
        begin
          state_new = block;
          state_we  = 1'h1;
        end

      if (next)
        begin
          state_we = 1'h1;
          state_new = rkey_state;
        end

      if (finalize)
        begin
          state_we  = 1'h1;
          state_new = state_reg ^ block;
        end
    end


  //----------------------------------------------------------------
  // round_key_logic
  //
  // Update logic for the round key generation.
  // Basically we shift with 12 bits for AES-128 and
  // 9 bits for AES-256. And we xor with final shifted key
  // after full processing.
  //----------------------------------------------------------------
  always @*
    begin : round_key_logic
      round_key_new = 128'h0;
      round_key_we  = 1'h0;

      if (init)
        begin
          round_key_new = key;
          round_key_we  = 1'h1;
        end

      if (next)
        begin
          round_key_we  = 1'h1;

          if (keylen)
            begin
              round_key_new = {round_key_reg[21 : 0],
                               round_key_reg[127 : 22]};
            end
          else
            begin
              round_key_new = {round_key_reg[18 : 0],
                               round_key_reg[127 : 19]};
            end
        end

      if (finalize)
        begin
          round_key_we  = 1'h1;
          round_key_new = round_key_reg ^ key;
        end
    end
endmodule // aes_mask_core

//======================================================================
// EOF aes_mask_core.v
//======================================================================
