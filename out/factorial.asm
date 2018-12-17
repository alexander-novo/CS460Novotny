	.data
	.text
# * CALL                                                  (LABEL main1)
jal	 main1
# * END
li	 $v0, 10
syscall
# ----------------------------
# | Original source          |
# ----------------------------
# * int main() {
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * LABEL             (LABEL main1)
main1:
# * PROCENTRY         (ICONS 12)        (ICONS 0)
subi	$sp, $sp, 12
sw	$ra, 8($sp)
# ----------------------------
# | Original source          |
# ----------------------------
# * 	int n = 7;
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * ASSIGN            (ICONS 7)                           (ILocal 4)
li	 $t0, 7

sw	 $t0, 4($sp)
# ----------------------------
# | Original source          |
# ----------------------------
# * 	int f = factorial(n);
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * ASSIGN            (ILocal 4)                          (ILocal -12)
lw	 $s0, 4($sp)

sw	 $s0, -12($sp)
# * CALL                                                  (LABEL factorial1)
jal	 factorial1
# * ASSIGN            (ILocal -4)                         (ILocal 0)
lw	 $s0, -4($sp)

sw	 $s0, 0($sp)
# ----------------------------
# | Original source          |
# ----------------------------
# * }
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * RETURN            (ICONS 8)         (ICONS 12)
lw	 $ra, 8($sp)
add	 $sp, $sp, 12
jr	 $ra
# ----------------------------
# | Original source          |
# ----------------------------
# * int factorial(int n) {
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * LABEL             (LABEL factorial1)
factorial1:
# * PROCENTRY         (ICONS 12)        (ICONS 4)
subi	$sp, $sp, 12
sw	$ra, 4($sp)
# ----------------------------
# | Original source          |
# ----------------------------
# * 	if (n <= 1)
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * LE                (ILocal 0)        (ICONS 1)         (ITemp 0)
lw	 $s0, 0($sp)
li	 $t0, 1
sle	 $t0, $s0, $t0
# * BREQ              (ITemp 0)         (ICONS 0)         (LABEL if0)
li	 $t1, 0
beq	 $t0, $t1, if0
# ----------------------------
# | Original source          |
# ----------------------------
# * 		return 1;
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * ASSIGN            (ICONS 1)                           (ILocal 8)
li	 $t0, 1

sw	 $t0, 8($sp)
# * RETURN            (ICONS 4)         (ICONS 12)
lw	 $ra, 4($sp)
add	 $sp, $sp, 12
jr	 $ra
# ----------------------------
# | Original source          |
# ----------------------------
# * 	if (n <= 1)
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * BR                                                    (LABEL if1)
b	 if1
# ----------------------------
# | Original source          |
# ----------------------------
# * 	}
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * LABEL             (LABEL if0)
if0:
# ----------------------------
# | Original source          |
# ----------------------------
# * 		return n * factorial(n - 1);
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * SUB               (ILocal 0)        (ICONS 1)         (ITemp 1)
lw	 $s0, 0($sp)
li	 $t0, 1
sub	 $t0, $s0, $t0
# * ASSIGN            (ITemp 1)                           (ILocal -12)

sw	 $t0, -12($sp)
# * CALL                                                  (LABEL factorial1)
sw $s0, 0($sp)
jal	 factorial1
# * MULT              (ILocal 0)        (ILocal -4)       (ITemp 2)
lw	 $s0, 0($sp)
lw	 $s1, -4($sp)
mul	 $t0, $s0, $s1
# * ASSIGN            (ITemp 2)                           (ILocal 8)

sw	 $t0, 8($sp)
# * RETURN            (ICONS 4)         (ICONS 12)
lw	 $ra, 4($sp)
add	 $sp, $sp, 12
jr	 $ra
# ----------------------------
# | Original source          |
# ----------------------------
# * 	}
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * LABEL             (LABEL if1)
if1:
# ----------------------------
# | Original source          |
# ----------------------------
# * }
# ----------------------------
# | 3 Address Code           |
# ----------------------------
# | op                op1               op2               dest
# | ----------------- ----------------- ----------------- ------------------
# * RETURN            (ICONS 4)         (ICONS 12)
lw	 $ra, 4($sp)
add	 $sp, $sp, 12
jr	 $ra
