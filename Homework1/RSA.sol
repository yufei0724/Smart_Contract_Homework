// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

/* 
* @title: RSA Cryptography
* @author: Tianchan Dong
* @notice: This contracts serves as an illustration of the cryptographic 
* mechanics in a blockchain.
*/ 

// Student: Yufei He (completed Exercise 2 Part A)

contract RSA{

    // Private key: (e, n)
    // Public key: (d, n)
    // For simplicity, the e(encrypt), d(decrypt) and n(modulo) 
    // has been "generated" for you. Do not modify
    uint private ENCRYPT = 7;
    uint private DECRYPT = 3;
    uint private MOD = 33;

    /// @param data The message to be hashed
    /// @return The hash value, or message digest, of the input
    function hash(string calldata data) public view returns(uint){
        uint digest = 0;

        // Convert the string to bytes
        bytes memory b = bytes(data);

        // Add the decimal (ASCII) value of each character together
        for (uint i = 0; i < b.length; i++) {
            digest += uint(uint8(b[i]));
        }

        // Take the modulo of this sum and return the result
        return digest % MOD;
    }

    /// @param data the original message
    /// @return a signed message of the *digest*
    function Sign_Message(string calldata data) public view returns(uint){
        // Call the hash function to create the message digest from user data
        uint digest = hash(data);

        // Sign the message with private key (digest^e % n)
        uint signed = powMod(digest, ENCRYPT, MOD);

        return signed;
    }

    /// @param data the original message
    /// @return true if the public key decrypts the signed message into the digest.
    function verify(string calldata data) public view returns(bool){
        // Create a signed message
        uint signed_message = Sign_Message(data);

        // Decrypt using public key: (signed^d % n)
        uint verify_with_public_key = powMod(signed_message, DECRYPT, MOD);

        // Get the digest
        uint digest = hash(data);

        // Check if the decrypted result matches the message digest
        return verify_with_public_key == digest;
    }

    /// @notice fast modular exponentiation: (base^exp) % mod
    function powMod(uint base, uint exp, uint mod) internal pure returns (uint) {
        uint result = 1;
        base = base % mod;

        while (exp > 0) {
            if (exp & 1 == 1) {
                result = (result * base) % mod;
            }
            base = (base * base) % mod;
            exp >>= 1;
        }
        return result;
    }
}
