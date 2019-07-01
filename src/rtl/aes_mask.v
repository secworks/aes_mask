//======================================================================
//
// aes_mask.v
// ----------
// Masking module for AES processing. Very experimental. Don't use
// before doing proper DPA analysis with the core and an a AES-core.
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

module aes_mask(
                input wire            clk,
                input wire            reset_n,

                input wire            init,
                input wire            next,
                input wire            finalize,

                input wire [127 : 0]  key,
                input wire            keylen,

                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           ready
               );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [127 : 0] round_key_reg;
  reg [127 : 0] round_key_new;
  reg           round_key_we;

  reg [127 : 0] state_reg;
  reg [127 : 0] state_new;
  reg           state_we;


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------


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
      state_new = 128'h0;
      state_we  = 1'h0;

      if (init)
        begin
          state_reg = block;
          state_we  = 1'h1;
        end


      if (next)
        begin
          state_we = 1'h1;

          // MixColumns


          // SubBytes


          // AddRoundKey
          state_new = state_reg ^ round_key_reg;
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
endmodule // aes_mask

//======================================================================
// EOF aes_mask.v
//======================================================================
