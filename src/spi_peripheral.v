`default_nettype none

module spi_peripheral (
    input wire COPI,
    input wire nCS,
    input wire SCLK,
    input wire clk,      // clock
    input wire rst_n,    // reset_n - low to reset
    output reg [7:0] en_reg_out_7_0,  // Enable output on lower 8 bits
    output reg [7:0] en_reg_out_15_8, // Enable output on upper 8 bits
    output reg [7:0] en_reg_pwm_7_0,  // Enable PWM on lower 8 bits
    output reg [7:0] en_reg_pwm_15_8, // Enable PWM on upper 8 bits
    output reg [7:0] pwm_duty_cycle   // PWM Duty cycle (0x00=0% to 0xFF=100%)
);

    reg [1:0] COPI_sync;
    reg [1:0] SCLK_sync;
    reg [1:0] nCS_sync;

    reg [15:0] spi_shift_reg;
    reg [3:0] bit_counter;

    // Synchronize SPI signals to internal clock domain
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            COPI_sync <= 2'b00;
            SCLK_sync <= 2'b00;
            nCS_sync <= 2'b11; 
        end else begin
            COPI_sync <= {COPI_sync[0], COPI};
            SCLK_sync <= {SCLK_sync[0], SCLK};
            nCS_sync <= {nCS_sync[0], nCS};
        end 
    end

    // Edge detection
    wire ncs_falling_edge = (nCS_sync[1] && !nCS_sync[0]);  
    wire ncs_rising_edge = (!nCS_sync[1] && nCS_sync[0]);   
    wire sclk_rising_edge = (!SCLK_sync[1] && SCLK_sync[0]); 

    // SPI transaction logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0 <= 8'b0;
            en_reg_out_15_8 <= 8'b0;
            en_reg_pwm_7_0 <= 8'b0;
            en_reg_pwm_15_8 <= 8'b0;
            pwm_duty_cycle <= 8'b0;
            spi_shift_reg <= 16'b0;
            bit_counter <= 4'b0;
        end else begin
            if (ncs_falling_edge) begin
                // Start of new SPI transaction
                bit_counter <= 4'b0;
                spi_shift_reg <= 16'b0;
            end else if (sclk_rising_edge && !nCS_sync[1]) begin
                spi_shift_reg <= {spi_shift_reg[14:0], COPI_sync[1]};
                bit_counter <= bit_counter + 1'b1;
            end else if (ncs_rising_edge) begin
                if (bit_counter == 4'd0) begin  
                    if (spi_shift_reg[15] == 1'b1) begin
                        case (spi_shift_reg[14:8])  
                            7'h00: en_reg_out_7_0 <= spi_shift_reg[7:0];    
                            7'h01: en_reg_out_15_8 <= spi_shift_reg[7:0];   
                            7'h02: en_reg_pwm_7_0 <= spi_shift_reg[7:0];    
                            7'h03: en_reg_pwm_15_8 <= spi_shift_reg[7:0];   
                            7'h04: pwm_duty_cycle <= spi_shift_reg[7:0];    
                            default: ; 
                        endcase
                    end
                end
                // Reset for next transaction
                bit_counter <= 4'b0;
                spi_shift_reg <= 16'b0;
            end
        end
    end

endmodule