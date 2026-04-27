`timescale 1ns / 1ps

module seven_seg_rpm_driver (
    input  wire clk_50M,
    input  wire rst_n,
   
    // Generic Data Input
    input  wire signed [15:0] speed_ticks,
   
    // Generic Hardware Outputs
    output reg  [3:0] dig_out,
    output reg  [7:0] seg_out
);

    // ==========================================
    // 1. Calculate Live Ticks
    // ==========================================
    wire [15:0] live_val = (speed_ticks[15]) ? -speed_ticks : speed_ticks;

    // ==========================================
    // 2. Sample-and-Hold Latch (10 Hz Refresh)
    // ==========================================
    reg [15:0] latched_val;
    reg [23:0] ui_timer;

    always @(posedge clk_50M) begin
        if (!rst_n) begin
            ui_timer <= 0;
            latched_val <= 0;
        end else begin
            if (ui_timer >= 24'd4_999_999) begin
                ui_timer <= 0;
                latched_val <= live_val;
            end else begin
                ui_timer <= ui_timer + 1;
            end
        end
    end

    // ==========================================
    // 3. Binary to BCD Converter
    // ==========================================
    reg [15:0] bcd_val;
    reg [13:0] bin_copy;
    integer i;
   
    always @(*) begin
        bcd_val = 16'b0;
        bin_copy = latched_val[13:0];
       
        for (i = 0; i < 14; i = i + 1) begin
            if (bcd_val[3:0]   >= 5) bcd_val[3:0]   = bcd_val[3:0]   + 4'd3;
            if (bcd_val[7:4]   >= 5) bcd_val[7:4]   = bcd_val[7:4]   + 4'd3;
            if (bcd_val[11:8]  >= 5) bcd_val[11:8]  = bcd_val[11:8]  + 4'd3;
            if (bcd_val[15:12] >= 5) bcd_val[15:12] = bcd_val[15:12] + 4'd3;
            bcd_val = {bcd_val[14:0], bin_copy[13-i]};
        end
    end

    // ==========================================
    // 4. Display Multiplexer & Decimal Point
    // ==========================================
    reg [15:0] refresh_counter = 0;
    reg [1:0]  digit_idx = 0;
   
    reg [3:0]  current_nibble;
    reg        dp_on;
    reg        blank_digit;

    always @(posedge clk_50M) begin
        if (!rst_n) begin
            refresh_counter <= 0;
            digit_idx <= 0;
        end else begin
            if (refresh_counter >= 16'd49_999) begin
                refresh_counter <= 0;
                digit_idx <= digit_idx + 1;
            end else begin
                refresh_counter <= refresh_counter + 1;
            end
        end
    end

    always @(*) begin
        case(digit_idx)
            2'd0: begin // Right-most digit (Tenths, e.g., the '9' in 1.9)
                current_nibble = bcd_val[3:0];  
                dig_out = 4'b1110;
                dp_on = 1'b0;
                blank_digit = 1'b0; // Never blank the tenths place
            end
            2'd1: begin // Second digit (Ones, e.g., the '1' in 1.9)
                current_nibble = bcd_val[7:4];  
                dig_out = 4'b1101;
                dp_on = 1'b1;       // TURN ON DECIMAL POINT HERE!
                blank_digit = 1'b0; // Never blank the ones place (so 0.5 shows "0.5", not ".5")
            end
            2'd2: begin // Third digit (Tens)
                current_nibble = bcd_val[11:8];  
                dig_out = 4'b1011;
                dp_on = 1'b0;
                // Blank if Hundreds and Tens are both zero
                blank_digit = (bcd_val[15:8] == 8'b0);
            end
            2'd3: begin // Left-most digit (Hundreds)
                current_nibble = bcd_val[15:12];
                dig_out = 4'b0111;
                dp_on = 1'b0;
                // Blank if Hundreds is zero
                blank_digit = (bcd_val[15:12] == 4'b0);
            end
        endcase
    end

    // ==========================================
    // 5. BCD to 7-Segment Decoder with DP Masking
    // ==========================================
    reg [7:0] seg_decoded;
   
    always @(*) begin
        // Standard 0-9 decoding
        case(current_nibble)
            4'h0: seg_decoded = 8'b00111111;
            4'h1: seg_decoded = 8'b00000110;
            4'h2: seg_decoded = 8'b01011011;
            4'h3: seg_decoded = 8'b01001111;
            4'h4: seg_decoded = 8'b01100110;
            4'h5: seg_decoded = 8'b01101101;
            4'h6: seg_decoded = 8'b01111101;
            4'h7: seg_decoded = 8'b00000111;
            4'h8: seg_decoded = 8'b01111111;
            4'h9: seg_decoded = 8'b01101111;
            default: seg_decoded = 8'b00000000;
        endcase
       
        // Apply Blanking and Decimal Point logic
        if (blank_digit)
            seg_out = 8'b00000000;               // Turn entirely off
        else if (dp_on)
            seg_out = seg_decoded | 8'b10000000; // Bitwise OR to force MSB (DP) high
        else
            seg_out = seg_decoded;               // Normal output
    end

endmodule