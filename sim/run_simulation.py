import os
import subprocess
import sys

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(base_dir)

    sim_dir = os.path.join(base_dir, "sim")
    os.makedirs(sim_dir, exist_ok=True)

    iverilog_exe = r"D:\CODE\GGANTIGRAVITY\iverilog\bin\iverilog.exe"
    vvp_exe = r"D:\CODE\GGANTIGRAVITY\iverilog\bin\vvp.exe"

    sources = [
        os.path.join("rtl", "intra", "intra_pred_4x4.v"),
        os.path.join("rtl", "transform", "h264_dct_4x4.v"),
        os.path.join("rtl", "quant", "h264_quantizer.v"),
        os.path.join("rtl", "entropy", "h264_cavlc_enc.v"),
        os.path.join("rtl", "top", "h264_macroblock_ctrl.v"),
        os.path.join("rtl", "h264_video_encoder_top.v"),
        os.path.join("tb", "tb_h264_encoder.v")
    ]

    out_vvp = os.path.join("sim", "h264_sim.vvp")

    cmd_compile = [iverilog_exe, "-g2012", "-o", out_vvp] + sources
    print("[SIM] Compiling Verilog sources with iverilog...")
    res = subprocess.run(cmd_compile, capture_output=True, text=True)
    if res.returncode != 0:
        print("[ERROR] iverilog compilation failed:")
        print(res.stderr)
        sys.exit(1)

    print("[SIM] Running simulation with vvp...")
    cmd_run = [vvp_exe, out_vvp]
    res_run = subprocess.run(cmd_run, capture_output=True, text=True)
    print(res_run.stdout)
    if res_run.stderr:
        print("[STDERR]", res_run.stderr)

    if "ALL 10 TESTS PASSED" in res_run.stdout:
        print("[SUCCESS] All 10 verification test cases passed successfully!")
        sys.exit(0)
    else:
        print("[FAILURE] Simulation did not pass all tests.")
        sys.exit(1)

if __name__ == "__main__":
    main()
