import random

DATA_WIDTH = 32
ACC_WIDTH = 68

NUM_MAC_GROUPS = 100
TERMS_PER_GROUP = 10

INPUT_FILE = "mac_input_vectors.hex"
GOLDEN_FILE = "mac_golden_outputs.hex"


def to_unsigned(value, bits):
    """將數值轉成指定 bit 寬度的 two's complement unsigned representation"""
    mask = (1 << bits) - 1
    return value & mask


def to_signed(value, bits):
    """將 unsigned two's complement 數值轉回 signed integer"""
    value &= (1 << bits) - 1

    if value & (1 << (bits - 1)):
        value -= 1 << bits

    return value


def generate_mac_vectors(
    num_groups=NUM_MAC_GROUPS, terms_per_group=TERMS_PER_GROUP, seed=12345
):
    random.seed(seed)

    with open(INPUT_FILE, "w") as f_in, open(GOLDEN_FILE, "w") as f_gold:
        total_vectors = 0
        total_results = 0

        for group in range(num_groups):
            # 產生一組 10 筆 MAC
            accumulator = 0

            for term in range(terms_per_group):
                # 第一筆：
                # i_acc_rst = 1
                if term == 0:
                    acc_rst = 1
                else:
                    acc_rst = 0

                calc_en = 1

                # 隨機產生 signed 32-bit data
                a = random.randint(
                    -(1 << (DATA_WIDTH - 1)), (1 << (DATA_WIDTH - 1)) - 1
                )

                b = random.randint(
                    -(1 << (DATA_WIDTH - 1)), (1 << (DATA_WIDTH - 1)) - 1
                )

                # 計算 signed multiplication
                product = a * b

                # 模擬 68-bit signed accumulator
                product_68 = to_signed(product, ACC_WIDTH)

                if term == 0:
                    accumulator = product_68
                else:
                    accumulator = accumulator + product_68
                    accumulator = to_signed(accumulator, ACC_WIDTH)

                # 第 10 筆時產生 Golden Result
                #
                # 這裡先讓 ready = 0，
                # 下一個 idle cycle 再讓 ready = 1，
                # 可以測試 valid hold。
                if term == terms_per_group - 1:
                    result_ready = 0
                else:
                    result_ready = 0

                # 寫入 input vector
                f_in.write(
                    f"{acc_rst} "
                    f"{calc_en} "
                    f"{to_unsigned(a, DATA_WIDTH):08X} "
                    f"{to_unsigned(b, DATA_WIDTH):08X} "
                    f"{result_ready}\n"
                )

                total_vectors += 1

            # 第 10 筆完成後：
            #
            # DUT:
            # o_result_valid = 1
            #
            # 下一個 cycle：
            # ready = 1
            # calc_en = 0
            #
            # 讓 DUT 清除 valid
            f_in.write("0 0 00000000 00000000 1\n")

            total_vectors += 1

            # Golden output：
            # 只在第 10 筆產生一次
            f_gold.write(f"{to_unsigned(accumulator, ACC_WIDTH):017X}\n")

            total_results += 1

        # 額外測試 idle cycles
        for _ in range(10):
            f_in.write("0 0 00000000 00000000 1\n")
            total_vectors += 1

    print("==========================================")
    print(" MAC Test Vector Generation Complete")
    print("==========================================")
    print(f"MAC groups       : {num_groups}")
    print(f"Terms / group   : {terms_per_group}")
    print(f"Input vectors    : {total_vectors}")
    print(f"Golden results   : {total_results}")
    print(f"Random seed      : {seed}")
    print("==========================================")


if __name__ == "__main__":
    generate_mac_vectors()
