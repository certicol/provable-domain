pragma solidity 0.5.3;

/**
 * @title Utility Contract
 *
 * @author Ken Sze <acken2@outlook.com>
 *
 * @notice This contract contains some helper functions used by the main contracts.
 */
contract util {

    /**
     * @notice Encode an address to its hex encoding
     * @param x address address to be encoded
     * @return string hex-encoded address
     * @dev original: https://ethereum.stackexchange.com/a/8447
     * @dev slightly modified to remove redundant casting
     */
    function toAsciiString(address x) public pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            /**
             * Extract the i-th byte from x in left-to-right manner
             *
             * Comment:
             *
             * 1. uint(x) converts the address into a single 20-byte number
             * 2. uint(x) / (2^(8 * (19 - i))) would produce an equivalent decimal
             * representation of all bytes above the i-th byte location. For instance,
             * if address is 0xF0E0D0, and i = 1 (2nd bytes or above), it would extract
             * the decimal equivalent of 0xF0E0, 0xD0 would be in the remainder and be
             * discarded
             * 3. By casting it to uint8, it always extract the RIGHTMOST byte in the
             * uint256 we get after the division. Thus, at i = 1, the division would
             * give 0xF0E0, and casting it to uint8 would yield us the decimal equivalent
             * of the rightmost byte - 0xE0
             * 4. By casting to byte, we obtain the i-th byte of the address - 0xE0
             * 5. Obviously, as i increases, we would extract from the leftmost byte
             * till the rightmost byte
             *
             */
            uint256 b = uint8(uint256(x) / (2**(8*(19 - i))));
            /**
             * Extract the leftmost 4-bit in a byte
             *
             * Similar to the above statement, by dividing the byte by 16, the leftmost
             * 4 bits would be in the quotient, while the rightmost 4 bits would be in the
             * remainder and be discarded.
             * For instance, 0xE0 = 224, and 224 / 16 = 14, or 0xE.
             */
            uint256 hi = b / 16;
            /**
             * Extract the rightmost (remaining) 4-bit in a byte
             *
             * This can be simply done by subtracting the decimal equivalent of the leftmost
             * 4 bits from the byte.
             * For instance, 0xE1 = 225, and 225 / 16 = 14...1, or 0xE. The leftmost 4 bits
             * represents 16 * 14 = 224, and therefore the leftmost 4 bits represents
             * 225 (original byte value) - 224 (leftmost 4 bits) = 1 - 0x01
             */
            uint256 lo = b - 16 * hi;
            // Character encode the high 4-bit (leftmost 4 bits in a byte)
            s[2*i] = char(hi);
            // Character encode the low 4-bit (rightmost 4 bits in a byte) next to the high 4-bit
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    /**
     * @notice ASCII encode a byte into its hexadecimal ASCII code
     * @param b uint256 the byte to be encoded where 0 <= b <= 15
     * @return byte the ASCII encoded byte
     * @dev original: https://ethereum.stackexchange.com/a/8447
     * @dev slightly modified to remove redundant casting
     */
    function char(uint256 b) public pure returns (byte c) {
        // Check if byte is a number from 0 to 0
        if (b < 10) {
            // Number from 0 to 9 is encoded from 0x30 (0) to 0x39 (9)
            return byte(uint8(b) + 0x30);
        }
        else {
            // Character from A to F is encoded from 0x61 (a) to 0x66 (f)
            // Thus, we starts from 0x57 since 0x57 + 0x0A = 0x61
            return byte(uint8(b) + 0x57);
        }
    }

}