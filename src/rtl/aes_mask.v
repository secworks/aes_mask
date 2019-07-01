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
                output wire           ready,

                input wire [127 : 0]  key,
                input wire            keylen,

                input wire [127 : 0]  block,
                output wire [127 : 0] result
               );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE  = 2'h0;
  localparam CTRL_INIT  = 2'h1;
  localparam CTRL_NEXT  = 2'h2;

  localparam AES_128_ROUNDS = 10;
  localparam AES_256_ROUNDS = 14;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [127 : 0] round_key_reg;
  reg [127 : 0] round_key_new;
  reg           round_key_we;
  reg           init_key;
  reg           next_key;
  reg           final_key;

  reg [127 : 0] state_reg;
  reg [127 : 0] state_new;
  reg           state_we;
  reg           init_state;
  reg           next_state;
  reg           final_state;

  reg [3 : 0]   round_ctr_reg;
  reg [3 : 0]   round_ctr_reg;
  reg           round_ctr_rst;
  reg           round_ctr_inc;
  reg           round_ctr_we;

  reg [1 : 0] core_ctrl_reg;
  reg [1 : 0] core_ctrl_new;
  reg         core_ctrl_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready  = ready_reg;
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
          round_ctr_reg <= 4'h0;
          round_key_reg <= 128'h0;
          state_reg     <= 128'h0;
          ready_reg     <= 1'h1;
          core_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (ready_we)
            ready_reg <= ready_new;

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (round_key_we)
            round_key_reg <= round_key_new;

          if (core_ctrl_we)
            core_ctrl_reg <= core_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // round_logic
  //
  // The actual round logic that causes the masking.
  //----------------------------------------------------------------
  always @*
    begin : round_key_logic
      state_new = 128'h0;
      state_we  = 1'h0;

      if (init_state)
        begin
          state_reg = block;
          state_we  = 1'h1;
        end


      if (next_state)
        begin
          state_we = 1'h1;

          // MixColumns


          // SubBytes


          // AddRoundKey
          state_we = state_reg ^ round_key_reg;
        end


      if (final_state)
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

      if (init_key)
        begin
          round_key_new = key;
          round_key_we  = 1'h1;
        end


      if (next_key)
        begin
          round_key_we  = 1'h1;

          if (keylen)
            begin
              round_key_new = {round_key_reg[21 : 0],
                               round_key_reg[31 : 22]};
            end
          else
            begin
              round_key_new = {round_key_reg[18 : 0],
                               round_key_reg[31 : 19]};
            end
        end


      if (final_key)
        begin
          round_key_we  = 1'h1;
          round_key_new = round_key_reg ^ key;
        end
    end


  //----------------------------------------------------------------
  // round_ctr_logic
  //
  // Update logic for the round counter.
  //----------------------------------------------------------------
  always @*
    begin : round_ctr_logic
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'h0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1'h1;
        end

      if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'h1;
          round_ctr_we  = 1'h1;
        end
    end


  //----------------------------------------------------------------
  // core_ctrl
  //
  // Control FSM.
  //----------------------------------------------------------------
  always @*
    begin : core_ctrl
      init_key      = 1'h0;
      next_key      = 1'h0;
      final_key     = 1'h0;
      init_state    = 1'h0;
      next_state    = 1'h0;
      final_state   = 1'h0;
      round_ctr_rst = 1'h0;
      round_ctr_inc = 1'h0;
      ready_new     = 1'h0;
      ready_we      = 1'h0;
      core_ctrl_new = CTRL_IDLE;
      core_ctrl_we  = 1'h0;

      case (core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                core_ctrl_new = CTRL_INIT;
                core_ctrl_we  = 1'b1;
              end
            else if (next)
              begin
                core_ctrl_new = CTRL_NEXT;
                core_ctrl_we  = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            core_ctrl_new = CTRL_IDLE;
            core_ctrl_we  = 1'b1;
          end

        CTRL_NEXT:
          begin
            core_ctrl_new = CTRL_IDLE;
            core_ctrl_we  = 1'b1;
          end

        default:
          begin

          end
      endcase // case (core_ctrl_reg)

    end // core_ctrl
endmodule // aes_mask

//======================================================================
// EOF aes_mask.v
//======================================================================
