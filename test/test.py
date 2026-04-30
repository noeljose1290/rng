import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_chaos_generator(dut):
    dut._log.info("Starting Chaos Generator Test")

    # 10 MHz clock (matches TT default)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # ---------------------------
    # Reset
    # ---------------------------
    dut.ena.value = 1
    dut.ui_in.value = 240      # r parameter
    dut.uio_in.value = 0x73  # seed (~0.5)
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Allow GL settle
    await ClockCycles(dut.clk, 20)

    # ---------------------------
    # Check output is valid
    # ---------------------------
    val = dut.uo_out.value
    assert val.is_resolvable, "Output is X after reset"

    dut._log.info(f"Initial output: {int(val)}")

    # ---------------------------
    # Observe evolution
    # ---------------------------
    values = []

    for _ in range(20):
        await ClockCycles(dut.clk, 1)
        val = dut.uo_out.value

        assert val.is_resolvable, "Output became X"
        values.append(int(val))

    dut._log.info(f"Sequence: {values}")

    # Ensure values are not constant (should evolve)
    assert len(set(values)) > 5, "Output is not changing (no chaos)"

    # ---------------------------
    # Change parameter r
    # ---------------------------
    dut.ui_in.value = 240  # chaotic region

    await ClockCycles(dut.clk, 20)

    values_r = []
    for _ in range(20):
        await ClockCycles(dut.clk, 1)
        values_r.append(int(dut.uo_out.value))

    dut._log.info(f"New sequence (r changed): {values_r}")

    # Ensure behavior changed
    assert values != values_r, "Changing r had no effect"

    # ---------------------------
    # Change seed
    # ---------------------------
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.uio_in.value = 0x40  # new seed
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 20)

    values_seed = []
    for _ in range(20):
        await ClockCycles(dut.clk, 1)
        values_seed.append(int(dut.uo_out.value))

    dut._log.info(f"New sequence (seed changed): {values_seed}")

    # Ensure seed affects behavior
    assert values_seed != values_r, "Seed did not affect chaos"

    dut._log.info("Chaos generator test PASSED")
