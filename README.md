### Setting up the USB Channel B in ECP5 Evaluation Board as a serial port

#### Motivation

[ECP5 Evaluation Board](http://www.latticesemi.com/-/media/LatticeSemi/Documents/UserManuals/EI2/FPGA-EB-02017-1-0-ECP5-Evaluation-Board.ashx?document_id=52479)
has a FT2232H IC that provides two USB channels: A and B. Channel A is used
to program the FPGA by tools like [OpenOCD](http://openocd.org/). Channel B, by
its turn, although not configured as a VCP (Virtual COM Port) can be used as a
standart serial port. Configuring channel B as **serial port 1** (to appear as
`/dev/ttyUSB1` on Linux) is convenient specially because it can be used as a
debug port for the ECP5 FPGA. This recipe provides the steps necessary to
setup channel B as serial port 1 plus a trivial example using Verilog HDL code
to generate a proper serial signal at 115200 8N1 transmitting character 'A'
through the wire so it can be read from `/dev/ttyUSB1`.

---

#### Steps

- **Solder** a jumper wire or a 0 ohm resistors at **R34 and R35** (please see
  board's User Guide). That will connect channel B TXD and RXD to the FPGA
- **Solder** a jumper wire or a 0 ohm resistor at **R21**. This is for the green
  LED D1 to blink when pin RXD (data from FPGA to FT2232) is toggled 
- Download [FT_PROG](https://www.ftdichip.com/Support/Utilities.htm#FT_PROG)
  (~~sorry, not sure if there is a way to avoid Windows using any alternative~~)
  **NOTE: as a cool alternative, you can use [Anton's method](https://github.com/antonblanchard/ftdi-eeprom-mod)**
- Connect the ECP5 board to the USB port and once in the *FT_PROG*, **go to
  Channel B settings (in Hardware) and select "RS232 Protocol", then click on
  _ray icon_ to make the change effective**. Board can be disconnect after it.
- Now attach the board again to the Linux box and using [raw_serial.sh](raw_serial.sh),
  burn [raw_serial.v](raw_serial.v) into ECP5 board
- After [raw_serial.v](raw_serial.v) is burned into the FPGA, you should open
  `/dev/ttyUSB1`(using Minicom, for instance) and voilà you should see a bunch
  of 'A's printed out to the terminal

---

### Simulation with Iverilog + GTKWave

#### Instalation

Ubuntu:

```bash
sudo apt-get install iverilog
sudo apt-get install gtkwave

```

Fedora:
```bash
sudo dnf install iverilog
sudo dnf install gtkwave
```

Dir `/sim` contains a quite simple example on how to simulate using Iverilog
and GTKWave. Just run [t_port.sh](/sim/t_port.sh) and it will compile the sim-
ulation example [t_port.v](/sim/t_port.sh) using Iverilog and then call GTKWave
to show the result. It's necessary to have `$DISPLAY` variable set correctly.
