# 🚀 DRAM Simulation Tool for RTL

This tool aids in system-level hardware simulations, particularly for large chip designs (RTL models) that require co-simulation with modern off-chip DRAMs (e.g., LPDDR, DDR, HBM). It utilizes [DRAMSys5.0](https://github.com/tukl-msd/DRAMSys) for the simulation of DRAM + CTRL models, setting up a co-simulation environment between RTL and DRAMSys5.0 effectively.

## 🚀 Getting Started

### 🔧 Prerequisites

- This tool leverages [`bender`](https://github.com/pulp-platform/bender) for dependency management and automatic generation of compilation scripts.
- Note: We currently do not offer an open-source simulation setup. Instead, we have utilized `Questasim` for simulation.
- For building DRAMSys, cmake version >= 3.28.1 is required.

### 🔨 Build DRAMSys Dynamic Linkable Library

Follow the steps below to build the DRAMSys dynamic linkable libraries:

1. Clone the DRAMSys5.0 repository and apply the necessary patches:
    ```shell
    cd dramsys_lib
    git clone https://github.com/tukl-msd/DRAMSys.git
    cd DRAMSys
    git reset --hard 8e021ea
    git apply ../dramsys_lib_patch
    ```

2. Build the DRAMSys dynamic linkable library within the `dramsys_lib/DRAMSys` directory:
    ```shell
    mkdir build
    cd build
    cmake -DCMAKE_CXX_FLAGS=-fPIC -DCMAKE_C_FLAGS=-fPIC -D DRAMSYS_WITH_DRAMPOWER=ON ..
    make -j
    ```
    After building, two key libraries will be available in `dramsys_lib/DRAMSys/build/lib`:
    - `libsystemc.so`
    - `libDRAMSys_Simulator.so`

### 🧪 (Optional) Test RTL-DRAMSys Co-simulation

From the root folder of this repository, use the command `make all` or `make gui` to run an RTL testbench that attempts to access DDR4-DIMM data.

### 📚 Using DRAMSys Dynamic Linkable Library for System-Level RTL+DRAMSys Co-simulation

**Steps**:

1. Include the following three SystemVerilog files from the `src` directory into your project. For example, you can add them to your `Bender.yml` source list:
   - `src/sim_dram.sv`
   - `src/axi_dram_sim.sv`
   - `src/dram_sim_engine.sv`

2. Instantiate **only one** `dram_sim_engine` in your design and set the parameter for your design's `clk period in ns`. It is recommended to place it in your top-level design.

3. Utilize the `axi_dram_sim` module as a standard SystemVerilog module with an AXI4 interface by:
   - Passing basic AXI interface parameters.
   - Specifying the DRAM model to simulate with the `DRAMType` parameter (defaults to `DDR4`).
   - Providing the base address of the DRAM model in your design.

4. For simulation in Modelsim, link Modelsim to the built libraries (`libsystemc.so` and `libDRAMSys_Simulator.so`) and specify the location of configuration files by passing the following arguments to your command:
    ```shell
    -sv_lib <library folder path>/libsystemc -sv_lib <library folder path>/libDRAMSys_Simulator +DRAMSYS_RES=<path to dramsys_lib/resources>
    ```

5. 💡 Now, you are ready to enjoy your DRAM simulation!

## 🎉 License

All hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see `LICENSE`). [DRAMSys5.0](https://github.com/tukl-msd/DRAMSys) is employed for DRAM simulations; please adhere to their [license](https://github.com/tukl-msd/DRAMSys) as well.
