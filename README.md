# UART Design in Verilog

## Project Introduction
Universal Asynchronous Receiver Transmitter (UART) is a communication protocol used to transfer data between a master and a slave.

UART frame format:
Start Bit | Data Bits (6–8 bits) | Parity Bit (Optional) | Stop Bit

This UART module consists of:
- Transmitter
- Receiver
- Baud Clock Generator

---

# Modules

1. UART Top Module
2. u_xmit – Transmitter
3. u_rec – Receiver
4. u_baud – Baud Clock Generator

---

# Input Parameters

| Signal | Description |
|--------|-------------|
| sys_clk | Main system clock |
| sys_rst_l | Active low reset |
| xmitH | Transmission enable |
| xmit_dataH | Parallel transmit data |
| uart_REC_dataH | Serial receive input |

---

# Output Parameters

| Signal | Description |
|--------|-------------|
| uart_XMIT_dataH | Serial transmit output |
| xmit_doneH | Transmission complete |
| rec_readyH | Receiver ready |
| rec_dataH | Parallel received data |
| rec_busyH | Receiver busy |
| xmit_active | Transmitter active |

---

# Working

## Transmitter FSM States
- IDLE
- SEND_STARTBIT
- SEND_DATA
- SEND_STOPBIT

## Receiver FSM States
- IDLE
- RECEIVING_DATA
- STOPBIT

---

# Features

- UART transmission and reception
- Configurable data width (6–8 bits)
- Oversampling receiver
- FSM-based architecture
- Serializer and deserializer logic
- Testbench support

---

# Tools Used

- Verilog HDL
- Icarus Verilog
- GTKWave

---

# Simulation

```bash
iverilog -o uart_tb tb_uart.v uart.v u_xmit.v u_rec.v u_baud.v
vvp uart_tb
gtkwave dump.vcd
