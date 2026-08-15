import random

INT32_MIN = -(2**31)
INT32_MAX = 2**31 - 1

UINT32_MASK = 0xFFFFFFFF
UINT68_MASK = (1 << 68) - 1

def to_unsigned(value, bits):
    """
    將 signed integer 轉成指定 bit 數的 two's complement 表示。
    """
    return value & ((1 << bits) - 1)

def generate_patterns(num_patterns=1000, group_size=10):
    """
    生成 32-bit signed input_a、input_b，並產生每 group_size 筆資料的 MAC Golden Result。

    """

    print("==================================================")
    print("       [Python] 開始生成隨機測資與 Golden Model")
    print("==================================================")

    # 1. 隨機生成 32-bit signed input data
    data_a = [
        random.randint(INT32_MIN, INT32_MAX)
        for _ in range(num_patterns)
    ]

    data_b = [
        random.randint(INT32_MIN, INT32_MAX)
        for _ in range(num_patterns)
    ]

    golden_results = []

    # 2. Golden Model
    for i in range(0, num_patterns, group_size):

        chunk_a = data_a[i:i + group_size]
        chunk_b = data_b[i:i + group_size]

        mac_sum = sum(
            a * b
            for a, b in zip(chunk_a, chunk_b)
        )

        golden_results.append(mac_sum)

    # 3. 輸出 input_a.hex
    with open("input_a.hex", "w") as fa:

        for val in data_a:

            unsigned_val = to_unsigned(val, 32)

            fa.write(
                f"{unsigned_val:08x}\n"
            )

    # 4. 輸出 input_b.hex
    with open("input_b.hex", "w") as fb:

        for val in data_b:

            unsigned_val = to_unsigned(val, 32)

            fb.write(
                f"{unsigned_val:08x}\n"
            )


    # 5. 輸出 golden.hex
    with open("golden.hex", "w") as fg:

        for val in golden_results:

            unsigned_val = to_unsigned(val, 68)

            fg.write(
                f"{unsigned_val:017x}\n"
            )

    # 6. 印出檔案資訊
    print(
        f"已成功生成 input_a.hex "
        f"與 input_b.hex "
        f"(各 {num_patterns} 筆)"
    )

    print(
        f"已成功生成 golden.hex "
        f"({len(golden_results)} 筆)"
    )

    print("")

    print("==================================================")
    print("       [Python] 測資與 Golden Model 生成完成")
    print("==================================================")

# Main
if __name__ == "__main__":

    generate_patterns(
        num_patterns=1000,
        group_size=10
    )
