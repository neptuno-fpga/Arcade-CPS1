/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtframe_mc2_base #(parameter
    CONF_STR        = "CORE",
    CONF_STR_LEN    = 4,
    SIGNED_SND      = 1'b0,
    COLORW          = 4
) (
    input           rst,
    input           clk_sys,
    input           clk_rom,
    input           SDRAM_CLK,      // SDRAM Clock
    output          osd_shown,
    output  [6:0]   core_mod,
    // Base video
    input   [1:0]   osd_rotate,
    input [COLORW-1:0] game_r,
    input [COLORW-1:0] game_g,
    input [COLORW-1:0] game_b,
    input           LHBL,
    input           LVBL,
    input           hs,
    input           vs, 
    input           pxl_cen,
    // Scan-doubler video
    input   [5:0]   scan2x_r,
    input   [5:0]   scan2x_g,
    input   [5:0]   scan2x_b,
    input           scan2x_hs,
    input           scan2x_vs,
    output          scan2x_enb, // scan doubler enable bar = scan doubler disable.
    input           scan2x_clk,
	 //input           w_scandoubler_disable, //delgrom
	 input    [1:0]  fn_pulse, //delgrom
    // Final video: VGA+OSD or base+OSD depending on configuration
    output  [5:0]   VIDEO_R,
    output  [5:0]   VIDEO_G,
    output  [5:0]   VIDEO_B,
    output          VIDEO_HS,
    output          VIDEO_VS,
    // SPI interface to arm io controller
    inout           SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // control
    output [31:0]   status,
    output [31:0]   joystick1,
    output [31:0]   joystick2,
    output [31:0]   joystick3,
    output [31:0]   joystick4,
    output [15:0]   joystick_analog_0,
    output [15:0]   joystick_analog_1,
    output          ps2_kbd_clk,
    output          ps2_kbd_data,
    // Sound
    input           clk_dac,
    input   [15:0]  snd_left,
    input   [15:0]  snd_right,
    output          snd_pwm_left,
    output          snd_pwm_right,
    // ROM load from SPI
    output [24:0]   ioctl_addr,
    output [ 7:0]   ioctl_data,
    output          ioctl_wr,
    output          downloading,

    //Multicore 2
    input       pll_locked,
    input [7:0] keys_i,
//    input wire  joy1_up_i,
//    input wire  joy1_down_i,
//    input wire  joy1_left_i,
//    input wire  joy1_right_i,
//    input wire  joy1_p6_i,
//    input wire  joy1_p9_i,
//    input wire  joy2_up_i,
//    input wire  joy2_down_i,
//    input wire  joy2_left_i,
//    input wire  joy2_right_i,
//    input wire  joy2_p6_i,
//    input wire  joy2_p9_i,
//    output wire joyX_p7_o,

	 
    output wire joy_clock_o,
    output wire joy_load_o,
    input  wire joy_data_i,
    output wire joyX_p7_o,

	 // I2S audio
	 output        i2s_mclk,
	 output 			i2s_bclk,
	 output 			i2s_lrclk,
	 output			i2s_data,
	 input         clock_i2s
);

wire        ypbpr;
wire [7:0]  ioctl_index;
wire        ioctl_download;

assign downloading = ioctl_download;

`ifndef SIMULATION
    `ifndef NOSOUND

    function [19:0] snd_padded;
        input [15:0] snd;
        reg   [15:0] snd_in;
        begin
            snd_in = {snd[15]^SIGNED_SND, snd[14:0]};
            snd_padded = { 1'b0, snd_in, 3'd0 };
        end
    endfunction
	 
	 // i2s audio
	audio_out i2s_audio_out  
   (
		.reset				( rst),
		.clk 					( clock_i2s),
		.sample_rate		(1'b0),  // 0 - 48KHz, 1 - 96KHz 
		.left_in				(snd_left),
		.right_in			(snd_right),
		.i2s_mclk			(i2s_mclk), 
		.i2s_bclk			(i2s_bclk),
		.i2s_lrclk			(i2s_lrclk),
		.i2s_data			(i2s_data)
   );	 
	 
	 

    hifi_1bit_dac u_dac_left
    (
      .reset    ( rst                  ),
      .clk      ( clk_dac              ),
      .clk_ena  ( 1'b1                 ),
      .pcm_in   ( snd_padded(snd_left) ),
      .dac_out  ( snd_pwm_left         )
    );

        `ifdef STEREO_GAME
        hifi_1bit_dac u_dac_right
        (
          .reset    ( rst                  ),
          .clk      ( clk_dac              ),
          .clk_ena  ( 1'b1                 ),
          .pcm_in   ( snd_padded(snd_right)),
          .dac_out  ( snd_pwm_right        )
        );
        `else
        assign snd_pwm_right = snd_pwm_left;
        `endif
    `endif
`else // Simulation:
assign snd_pwm_left = 1'b0;
assign snd_pwm_right = 1'b0;
`endif

`ifndef JTFRAME_MIST_DIRECT
`define JTFRAME_MIST_DIRECT 1'b1
`endif


`ifndef SIMULATION
/*user_io #(.STRLEN(CONF_STR_LEN), .ROM_DIRECT_UPLOAD(`JTFRAME_MIST_DIRECT)) u_userio(
    .rst            ( rst       ),
    .clk_sys        ( clk_sys   ),
    .conf_str       ( CONF_STR  ),
    .SPI_CLK        ( SPI_SCK   ),
    .SPI_SS_IO      ( CONF_DATA0),
    .SPI_MISO       ( SPI_DO    ),
    .SPI_MOSI       ( SPI_DI    ),
    .joystick_0     ( joystick2 ),
    .joystick_1     ( joystick1 ),
    .joystick_3     ( joystick3 ),
    .joystick_4     ( joystick4 ),
    // Analog joysticks
    .joystick_analog_0  ( joystick_analog_0 ),
    .joystick_analog_1  ( joystick_analog_1 ),
    
    .status         ( status    ),
    .ypbpr          ( ypbpr     ),
    .scandoubler_disable ( scan2x_enb ),
    // keyboard
    .ps2_kbd_clk    ( ps2_kbd_clk  ),
    .ps2_kbd_data   ( ps2_kbd_data ),
    // Core variant
    .core_mod       ( core_mod  ),
    // unused ports:
    .serial_strobe  ( 1'b0      ),
    .serial_data    ( 8'd0      ),
    .sd_lba         ( 32'd0     ),
    .sd_rd          ( 1'b0      ),
    .sd_wr          ( 1'b0      ),
    .sd_conf        ( 1'b0      ),
    .sd_sdhc        ( 1'b0      ),
    .sd_din         ( 8'd0      )
);*/
//assign scan2x_enb = (cnt_scandbldis)? w_scandoubler_disable : status[6];// delgrom
//assign scan2x_enb = w_scandoubler_disable;// delgrom


assign scan2x_enb = (cnt_changeScandoubler == 1'b0 & cnt_osdenable == 1'b0) ? status[6] :  
						 ((cnt_changeScandoubler == 1'b0 & cnt_osdenable == 1'b1) ? scan2x_enb : v_scandoublerD);


`else
assign joystick1 = 32'd0;
assign joystick2 = 32'd0;
assign joystick3 = 32'd0;
assign joystick4 = 32'd0;
assign status    = 32'd0;
assign ps2_kbd_data = 1'b0;
assign ps2_kbd_clk  = 1'b0;
`ifndef SCANDOUBLER_DISABLE
    `define SCANDOUBLER_DISABLE 1'b1
    initial $display("INFO: Use -d SCANDOUBLER_DISABLE=0 if you want video output.");
`endif
initial $display("INFO:SCANDOUBLER_DISABLE=%d",`SCANDOUBLER_DISABLE);
assign scan2x_enb = `SCANDOUBLER_DISABLE;
assign ypbpr = 1'b0;
`endif

//assign status[31:16] = 16'b1001110000000100;
//assign status[15:0 ] = 16'b1011011000000000;

data_io  #(.STRLEN(CONF_STR_LEN)) u_datain (
    .SPI_SCK            ( SPI_SCK           ),
    .SPI_SS2            ( SPI_SS2           ),
    .SPI_DI             ( SPI_DI            ),
    .SPI_DO             ( SPI_DO            ),
    
    .data_in            ( osd_s & keys_i    ),
    .conf_str           ( CONF_STR          ),
    .status             ( status            ),
    .core_mod           ( core_mod          ),

    .clk_sys            ( clk_rom           ),
 //   .clkref_n           ( 1'b0              ), // this is not a clock.
    .ioctl_download     ( ioctl_download    ),
    .ioctl_addr         ( ioctl_addr        ),
    .ioctl_dout         ( ioctl_data        ),
    .ioctl_wr           ( ioctl_wr          ),
    .ioctl_index        ( ioctl_index       )
    // Unused:
//    .ioctl_fileext      (                   ),
//    .ioctl_filesize     (                   )
);

// OSD will only get simulated if SIMULATE_OSD is defined
`ifndef SIMULATE_OSD
`ifndef SCANDOUBLER_DISABLE
`ifdef SIMULATION
`define BYPASS_OSD
`endif
`endif
`endif

`ifdef SIMINFO
initial begin
    $display("INFO: use -d SIMULATE_OSD to simulate the MiST OSD")
end
`endif


`ifndef BYPASS_OSD
// include the on screen display
wire [5:0] osd_r_o;
wire [5:0] osd_g_o;
wire [5:0] osd_b_o;
wire       HSync = scan2x_enb ? ~hs : scan2x_hs;
wire       VSync = scan2x_enb ? ~vs : scan2x_vs;
wire       HSync_osd, VSync_osd;
wire       CSync_osd = ~(HSync_osd ^ VSync_osd);

function [5:0] extend_color;
    input [COLORW-1:0] a;
    case( COLORW )
        3: extend_color = { a, a[2:0] };
        4: extend_color = { a, a[3:2] };
        5: extend_color = { a, a[4] };
        6: extend_color = a;
        7: extend_color = a[6:1];
        8: extend_color = a[7:2];
    endcase
endfunction

wire [5:0] game_r6 = extend_color( game_r );
wire [5:0] game_g6 = extend_color( game_g );
wire [5:0] game_b6 = extend_color( game_b );


osd #(0,0,6'b01_11_01) osd (
   .clk_sys    ( scan2x_enb ? clk_sys : scan2x_clk ),

   // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS2      ),

   .rotate     ( osd_rotate   ),

   .R_in       ( scan2x_enb ? game_r6 : scan2x_r ),
   .G_in       ( scan2x_enb ? game_g6 : scan2x_g ),
   .B_in       ( scan2x_enb ? game_b6 : scan2x_b ),
   .HSync      ( HSync        ),
   .VSync      ( VSync        ),

   .R_out      ( osd_r_o      ),
   .G_out      ( osd_g_o      ),
   .B_out      ( osd_b_o      ),
   .HSync_out  ( HSync_osd    ),
   .VSync_out  ( VSync_osd    ),

   .osd_shown  ( osd_shown    )
);

wire [5:0] Y, Pb, Pr;

wire [5:0] r, g, b;
wire [1:0] scanlines = status[4:3];
reg  [5:0] sl_r_s, sl_g_s, sl_b_s;
reg  scanline;

always @(negedge HSync) begin
	scanline <= !scanline;
end

rgb2ypbpr u_rgb2ypbpr
(
    .red   ( osd_r_o ),
    .green ( osd_g_o ),
    .blue  ( osd_b_o ),
    .y     ( Y       ),
    .pb    ( Pb      ),
    .pr    ( Pr      )
);

assign r = ypbpr ? Pr : osd_r_o;
assign g = ypbpr ? Y  : osd_g_o;
assign b = ypbpr ? Pb : osd_b_o;

assign VIDEO_R = sl_r_s;
assign VIDEO_G = sl_g_s;
assign VIDEO_B = sl_b_s;

always @(posedge clk_sys) begin
	case(scanlines)
		0: begin // no scanlines
			sl_r_s = r;
			sl_g_s = g;
			sl_b_s = b;
		end
		1: begin // reduce 25% = 1/2 + 1/4
			sl_r_s = scanline ? r : { 1'b0, r[5:1] } + { 2'b00, r[5:2] };
			sl_g_s = scanline ? g : { 1'b0, g[5:1] } + { 2'b00, g[5:2] };
			sl_b_s = scanline ? b : { 1'b0, b[5:1] } + { 2'b00, b[5:2] };
		end
		2: begin // reduce 50% = 1/2
			sl_r_s = scanline ? r : { 1'b0, r[5:1] };
			sl_g_s = scanline ? g : { 1'b0, g[5:1] };
			sl_b_s = scanline ? b : { 1'b0, b[5:1] };
		end
		3: begin // reduce 75% = 1/4
			sl_r_s = scanline ? r : { 2'b00, r[5:2] };
			sl_g_s = scanline ? g : { 2'b00, g[5:2] };
			sl_b_s = scanline ? b : { 2'b00, b[5:2] };
		end
	endcase
end

assign ypbpr = 0;
//assign scan2x_enb = 0; //delgrom
//assign VIDEO_R  = ypbpr?Pr:osd_r_o;
//assign VIDEO_G  = ypbpr? Y:osd_g_o;
//assign VIDEO_B  = ypbpr?Pb:osd_b_o;
// a minimig vga->scart cable expects a composite sync signal on the VIDEO_HS output.
// and VCC on VIDEO_VS (to switch into rgb mode)
assign VIDEO_HS = (scan2x_enb | ypbpr) ? CSync_osd : HSync_osd;
assign VIDEO_VS = (scan2x_enb | ypbpr) ? 1'b1 : VSync_osd;
`else
assign VIDEO_R  = game_r;// { game_r, game_r[3:2] };
assign VIDEO_G  = game_g;// { game_g, game_g[3:2] };
assign VIDEO_B  = game_b;// { game_b, game_b[3:2] };
assign VIDEO_HS = hs;
assign VIDEO_VS = vs;
`endif

//--------- ROM DATA PUMP ----------------------------------------------------
    
        reg [15:0] power_on_s   = 16'b1111111111111111;
        reg [7:0] osd_s = 8'b11111111;
        
        wire hard_reset = ~pll_locked;
        
        //--start the microcontroller OSD menu after the power on
        always @(posedge clk_sys) 
        begin
        
                if (hard_reset == 1)
                    power_on_s = 16'b1111111111111111;
                else if (power_on_s != 0)
                begin
                    power_on_s = power_on_s - 1;
                    osd_s = 8'b00111111;
                end 
                    
                
                if (downloading == 1 && osd_s == 8'b00111111)
                    osd_s = 8'b11111111;
            
        end 

//-----------------------

// delgrom: First start with video mode from config, and change between 15khz and 31khz

reg v_scandoublerD = 1'b0;
reg cnt_changeScandoubler = 1'b0;
reg cnt_osdenable = 1'b0;

always @(posedge fn_pulse[0]) // Scroll lock key pressed
begin		
	v_scandoublerD <= ~scan2x_enb; 
	cnt_changeScandoubler = 1'b1;
end

always @( posedge fn_pulse[1] ) // F12 (Menu) key pressed
begin		
	cnt_osdenable = 1'b1;
end
// ---------------------------------------------

reg clk_sega_s;

//parameter CLOCK = 50;
//localparam TIMECLK = (9 / (1 / CLOCK)) / 2; //calculate 9us state time based on input clock
reg [9:0] delay;

always@(posedge clk_sys)
begin
    delay <= delay - 10'd1;
    
    if (delay == 10'd0) 
        begin
            clk_sega_s <= ~clk_sega_s;
            delay <= 10'd432; // ~9us state cycle 
        end
end


reg joy1_up_q   ; reg joy1_up_0;
reg joy1_down_q ; reg joy1_down_0;
reg joy1_left_q ; reg joy1_left_0;
reg joy1_right_q; reg joy1_right_0;
reg joy1_p6_q   ; reg joy1_p6_0;
reg joy1_p9_q   ; reg joy1_p9_0;

reg joy2_up_q   ; reg joy2_up_0;
reg joy2_down_q ; reg joy2_down_0;
reg joy2_left_q ; reg joy2_left_0;
reg joy2_right_q; reg joy2_right_0;
reg joy2_p6_q   ; reg joy2_p6_0;
reg joy2_p9_q   ; reg joy2_p9_0;

   always @(posedge clk_sys) 
   begin
         joy1_up_0    <= joy1_up_i;
         joy1_down_0  <= joy1_down_i;
         joy1_left_0  <= joy1_left_i;
         joy1_right_0 <= joy1_right_i;
         joy1_p6_0    <= joy1_p6_i;
         joy1_p9_0    <= joy1_p9_i;
      
         joy2_up_0    <= joy2_up_i;
         joy2_down_0  <= joy2_down_i;
         joy2_left_0  <= joy2_left_i;
         joy2_right_0 <= joy2_right_i;
         joy2_p6_0    <= joy2_p6_i;
         joy2_p9_0    <= joy2_p9_i;
   end 
   
    always @(posedge clk_sys) 
   begin
         joy1_up_q    <= joy1_up_0;
         joy1_down_q  <= joy1_down_0;
         joy1_left_q  <= joy1_left_0;
         joy1_right_q <= joy1_right_0;
         joy1_p6_q    <= joy1_p6_0;
         joy1_p9_q    <= joy1_p9_0;

         joy2_up_q    <= joy2_up_0;
         joy2_down_q  <= joy2_down_0;
         joy2_left_q  <= joy2_left_0;
         joy2_right_q <= joy2_right_0;
         joy2_p6_q    <= joy2_p6_0;
         joy2_p9_q    <= joy2_p9_0;
     
   end






//--- Joystick read with sega 6 button support----------------------
  //  --medio, forte, fraco

    //assign joystick1[31:10] = 22'd0;
    //assign joystick2[31:10] = 22'd0;

//  assign joystick1[9:0] = { ~joy1_s[5], ~joy1_s[4], ~joy1_s[6], ~joy1_s[9], ~joy1_s[10], ~joy1_s[8], ~joy1_s[0], ~joy1_s[1], ~joy1_s[2], ~joy1_s[3] };
//  assign joystick2[9:0] = { ~joy2_s[5], ~joy2_s[4], ~joy2_s[6], ~joy2_s[9], ~joy2_s[10], ~joy2_s[8], ~joy2_s[0], ~joy2_s[1], ~joy2_s[2], ~joy2_s[3] };


    //botao certo, leitura do 6bts nao funciona
    //assign joystick1[9:0] = { ~joy1_s[8], ~joy1_s[9], ~joy1_s[10], ~joy1_s[5], ~joy1_s[4], ~joy1_s[6], ~joy1_s[0], ~joy1_s[1], ~joy1_s[2], ~joy1_s[3] };
    //assign joystick2[9:0] = { ~joy2_s[8], ~joy2_s[9], ~joy2_s[10], ~joy2_s[5], ~joy2_s[4], ~joy2_s[6], ~joy2_s[0], ~joy2_s[1], ~joy2_s[2], ~joy2_s[3] };

	 
	 // delgrom: Add possibility of change kick and punch buttons in 6 buttons games
	 
	 //joyX_s
	 //1098 7654 3210
	 //MXYZ SACB RLDU
 
    assign joystick1[31:12] = 22'd0;
    assign joystick2[31:12] = 22'd0;


    assign joystick1[11:10] = { ~joy1_s[11],  ~joy1_s[7]}; // Coin, start
    assign joystick2[11:10] = { ~joy2_s[11],  ~joy2_s[7]};	 

	 
	 //assign joystick1[9:0] = { status[5]? ~joy1_s[5]: ~joy1_s[8], status[5]? ~joy1_s[4] : ~joy1_s[9], status[5]? ~joy1_s[6]: ~joy1_s[10], status[5]?  ~joy1_s[8]: ~joy1_s[5], status[5]? ~joy1_s[9] : ~joy1_s[4], status[5]? ~joy1_s[10] : ~joy1_s[6], ~joy1_s[0], ~joy1_s[1], ~joy1_s[2], ~joy1_s[3] };
	 //assign joystick2[9:0] = { status[5]? ~joy2_s[5]: ~joy2_s[8], status[5]? ~joy2_s[4] : ~joy2_s[9], status[5]? ~joy2_s[6]: ~joy2_s[10], status[5]?  ~joy2_s[8]: ~joy2_s[5], status[5]? ~joy2_s[9] : ~joy2_s[4], status[5]? ~joy2_s[10] : ~joy2_s[6], ~joy2_s[0], ~joy2_s[1], ~joy2_s[2], ~joy2_s[3] };
	 
	 
	 assign joystick1[9:0] = { status[5]? ~joy1_s[5]: ~joy1_s[8], status[5]? ~joy1_s[4] : ~joy1_s[9], status[5]? ~joy1_s[6]: ~joy1_s[10], status[5]?  ~joy1_s[8]: ~joy1_s[5], status[5]? ~joy1_s[9] : ~joy1_s[4], status[5]? ~joy1_s[10] : ~joy1_s[6], ~joy1_s[3], ~joy1_s[2], ~joy1_s[1], ~joy1_s[0] };
	 assign joystick2[9:0] = { status[5]? ~joy2_s[5]: ~joy2_s[8], status[5]? ~joy2_s[4] : ~joy2_s[9], status[5]? ~joy2_s[6]: ~joy2_s[10], status[5]?  ~joy2_s[8]: ~joy2_s[5], status[5]? ~joy2_s[9] : ~joy2_s[4], status[5]? ~joy2_s[10] : ~joy2_s[6], ~joy2_s[3], ~joy2_s[2], ~joy2_s[1], ~joy2_s[0] };	 

	 
    reg [11:0]joy1_s;   
    reg [11:0]joy2_s; 
    //reg joyP7_s;
	 
	 
	 
	 
	 

wire joy1_up_i, joy1_down_i, joy1_left_i, joy1_right_i, joy1_p6_i, joy1_p9_i;
wire joy2_up_i, joy2_down_i, joy2_left_i, joy2_right_i, joy2_p6_i, joy2_p9_i;

joydecoder joystick_serial  (
    .clk          ( clk_sys ), 	 
    .joy_data     ( joy_data_i ),
    .joy_clk      ( joy_clock_o ),
    .joy_load     ( joy_load_o ),
	 .clock_locked ( pll_locked ),

    .joy1up       ( joy1_up_i ),
    .joy1down     ( joy1_down_i ),
    .joy1left     ( joy1_left_i ),
    .joy1right    ( joy1_right_i ),
    .joy1fire1    ( joy1_p6_i ),
    .joy1fire2    ( joy1_p9_i ),

    .joy2up       ( joy2_up_i ),
    .joy2down     ( joy2_down_i ),
    .joy2left     ( joy2_left_i ),
    .joy2right    ( joy2_right_i ),
    .joy2fire1    ( joy2_p6_i ),
    .joy2fire2    ( joy2_p9_i )
); 
	 
	 
	 
//translate scancode to joystick
joystick_sega joystick
(
	.joy0 		 ({ joy1_p9_i, joy1_p6_i, joy1_up_i, joy1_down_i, joy1_left_i, joy1_right_i }),
	.joy1	  		 ({ joy2_p9_i, joy2_p6_i, joy2_up_i, joy2_down_i, joy2_left_i, joy2_right_i }),

	.player1     ( joy1_s ),
	.player2     ( joy2_s ),
		
	//.sega_clk    ( clk_sega_s ),
	.sega_clk    ( HSync ),
	.sega_strobe ( joyX_p7_o )	
);	 

	
	 
/*
    reg [7:0]state_v = 8'd0;
    reg j1_sixbutton_v = 1'b0;
    reg j2_sixbutton_v = 1'b0;
    
    always @(negedge clk_sega_s) 
	 //always @(negedge HSync) 
    begin
        

            state_v <= state_v + 8'd1;

            
            case (state_v)          //-- joy_s format MXYZ SACB RLDU
                8'd0:  
                    joyP7_s <=  1'b0;
                    
                8'd1:
                    joyP7_s <=  1'b1;

                8'd2:
                    begin
                        joy1_s[3:0] <= {joy1_right_q, joy1_left_q, joy1_down_q, joy1_up_q}; //-- R, L, D, U
                        joy2_s[3:0] <= {joy2_right_q, joy2_left_q, joy2_down_q, joy2_up_q}; //-- R, L, D, U
                        joy1_s[5:4] <= {joy1_p9_q, joy1_p6_q}; //-- C, B
                        joy2_s[5:4] <= {joy2_p9_q, joy2_p6_q}; //-- C, B                    
                        joyP7_s <= 1'b0;
                        j1_sixbutton_v <= 1'b0; //-- Assume it's not a six-button controller
                        j2_sixbutton_v <= 1'b0; //-- Assume it's not a six-button controller
                    end
                    
                8'd3:
                    begin
                        if (joy1_right_q == 1'b0 && joy1_left_q == 1'b0) // it's a megadrive controller
                                joy1_s[7:6] <= { joy1_p9_q , joy1_p6_q }; //-- Start, A
                        else
                                joy1_s[7:4] <= { 1'b1, 1'b1, joy1_p9_q, joy1_p6_q }; //-- read A/B as master System
                            
                        if (joy2_right_q == 1'b0 && joy2_left_q == 1'b0) // it's a megadrive controller
                                joy2_s[7:6] <= { joy2_p9_q , joy2_p6_q }; //-- Start, A
                        else
                                joy2_s[7:4] <= { 1'b1, 1'b1, joy2_p9_q, joy2_p6_q }; //-- read A/B as master System

                            
                        joyP7_s <= 1'b1;
                    end
                    
                8'd4:  
                    joyP7_s <= 1'b0;

                8'd5:
                    begin
                        if (joy1_down_q == 1'b0 && joy1_up_q == 1'b0 )
                            j1_sixbutton_v <= 1'b1; // --it's a six button
                        
                        
                        if (joy2_down_q == 1'b0 && joy2_up_q == 1'b0 )
                            j2_sixbutton_v <= 1'b1; // --it's a six button
                        
                        
                        joyP7_s <= 1'b1;
                    end
                    
                8'd6:
                    begin
                        if (j1_sixbutton_v == 1'b1)
                            joy1_s[11:8] <= { joy1_right_q, joy1_left_q, joy1_down_q, joy1_up_q }; //-- Mode, X, Y e Z
                        
                        
                        if (j2_sixbutton_v == 1'b1)
                            joy2_s[11:8] <= { joy2_right_q, joy2_left_q, joy2_down_q, joy2_up_q }; //-- Mode, X, Y e Z
                        
                        
                        joyP7_s <= 1'b0;
                    end 
                    
                default:
                    joyP7_s <= 1'b1;
                    
            endcase

    end
    
    assign joyX_p7_o = joyP7_s;
    //---------------------------
*/
endmodule