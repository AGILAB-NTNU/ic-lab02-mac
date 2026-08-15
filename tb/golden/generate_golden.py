#!/usr/bin/env python3
# =============================================================================
# generate_golden.py
#
# 功能說明:
#   為 MAC (Multiply-Accumulate) 系統產生隨機測試向量與 Golden Data。
#   - 隨機產生 M 組長度為 N=10 的向量 A[] 與 B[]
#   - 將 A[] / B[] 依序 (M*N 筆) 寫入 input_A.hex / input_B.hex (16 進位格式)
#   - 針對每一組 (block) 計算 Sum = Σ (A[i] * B[i])，i=0..N-1
#     並寫入 golden_sum.hex，供 RTL 模擬結果手動比對
#
# 輸出檔案格式:
#   input_A.hex / input_B.hex : 每行一筆 8-bit 資料的十六進位表示 (2 個字元)，
#                                 可直接被 Verilog $readmemh 讀取
#   golden_sum.hex            : 每行一筆 20-bit 累加結果的十六進位表示 (5 個字元)
#
# 使用方式:
#   python3 generate_golden.py [--m M] [--n N] [--seed SEED] [--outdir OUTDIR]
# =============================================================================

import argparse
import random
import os


def generate_golden_data(m: int, n: int, data_width: int, seed: int, outdir: str):
    """
    產生隨機測試向量並計算 Golden Sum。

    參數:
        m          : 要產生幾組 (block) 測試向量
        n          : 每組向量的長度 (對應 RTL 中的 N=10)
        data_width : A/B 資料的位元寬度 (預設 8-bit)
        seed       : 亂數種子，確保可重現 (reproducible)
        outdir     : 輸出檔案目錄
    """
    random.seed(seed)

    max_val = (1 << data_width) - 1   # 8-bit 資料範圍: 0 ~ 255

    a_all_flat = []   # 攤平後的 A 資料 (共 M*N 筆)，依序寫入 input_A.hex
    b_all_flat = []   # 攤平後的 B 資料 (共 M*N 筆)，依序寫入 input_B.hex
    golden_sums = []  # 每個 block 的累加結果 (共 M 筆)

    for blk in range(m):
        a_vec = [random.randint(0, max_val) for _ in range(n)]
        b_vec = [random.randint(0, max_val) for _ in range(n)]

        # 計算本區塊 (block) 的累加總和: Sum = sum(A[i] * B[i])
        block_sum = sum(a * b for a, b in zip(a_vec, b_vec))

        a_all_flat.extend(a_vec)
        b_all_flat.extend(b_vec)
        golden_sums.append(block_sum)

        print(f"[Block {blk:3d}] A={a_vec}")
        print(f"           B={b_vec}")
        print(f"           Golden Sum = {block_sum} (0x{block_sum:05X})")
        print("-" * 70)

    os.makedirs(outdir, exist_ok=True)

    # ---------------- 寫出 input_A.hex ----------------
    a_path = os.path.join(outdir, "input_A.hex")
    with open(a_path, "w") as f:
        for val in a_all_flat:
            f.write(f"{val:02X}\n")   # 8-bit -> 2 個十六進位字元

    # ---------------- 寫出 input_B.hex ----------------
    b_path = os.path.join(outdir, "input_B.hex")
    with open(b_path, "w") as f:
        for val in b_all_flat:
            f.write(f"{val:02X}\n")

    # ---------------- 寫出 golden_sum.hex ----------------
    # Accumulator 位元寬度 = 2*data_width + ceil(log2(n))，這裡固定用 20-bit (5 hex 字元)
    # 若使用者調整 n/data_width，仍保留 5 字元寬 (可容納到 24-bit)；
    # 如需更精確位寬，可自行依 ACC_W 調整下面的格式化寬度。
    sum_path = os.path.join(outdir, "golden_sum.hex")
    with open(sum_path, "w") as f:
        for s in golden_sums:
            f.write(f"{s:05X}\n")   # 20-bit -> 5 個十六進位字元

    print("=" * 70)
    print(f"共產生 {m} 組 (block)，每組 {n} 筆資料 (共 {m*n} 筆 A/B 資料點)")
    print(f"輸出檔案:")
    print(f"  A 資料 : {a_path}")
    print(f"  B 資料 : {b_path}")
    print(f"  Golden Sum : {sum_path}")
    print("=" * 70)

    return a_all_flat, b_all_flat, golden_sums


def main():
    parser = argparse.ArgumentParser(
        description="產生 MAC 系統的隨機測試向量與 Golden Data"
    )
    parser.add_argument("--m", type=int, default=5,
                         help="要產生幾組(block)測試向量 (預設: 5)")
    parser.add_argument("--n", type=int, default=10,
                         help="每組向量長度，對應 RTL 的 N (預設: 10)")
    parser.add_argument("--data-width", type=int, default=8,
                         help="A/B 資料位元寬度 (預設: 8-bit)")
    parser.add_argument("--seed", type=int, default=42,
                         help="亂數種子，確保結果可重現 (預設: 42)")
    parser.add_argument("--outdir", type=str, default=".",
                         help="輸出檔案目錄 (預設: 目前目錄)")

    args = parser.parse_args()

    generate_golden_data(
        m=args.m,
        n=args.n,
        data_width=args.data_width,
        seed=args.seed,
        outdir=args.outdir,
    )


if __name__ == "__main__":
    main()
