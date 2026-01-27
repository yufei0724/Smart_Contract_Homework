// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

/* 
* @title: Subnet Masking
* @author: Tianchan Dong
* @notice: This contract illustrate how IP addresses are distributed and calculated
* @notice: This contract has no sanity checks! Only use numbers provided in constructor
*/ 

// Student: Yufei He (completed Exercise 2 Part B)

contract Masking{

    // Return Variables
    string public Country;
    string public ISP;
    string public Institute;
    string public Device;

    // Maps of IP interpretation
    mapping(uint => string) public Countries;
    mapping(uint => string) public ISPs;
    mapping(uint => string) public Institutions;
    mapping(uint => string) public Devices;

    constructor() {
        Countries[34] = "Botswana";
        Countries[58] = "Egypt";
        Countries[125] = "Brazil";
        Countries[148] = "USA";
        Countries[152] = "France";
        Countries[196] = "Singapore";
        ISPs[20] = "Orange";
        ISPs[47] = "Telkom";
        ISPs[139] = "Vodafone";
        Institutions[89] = "University";
        Institutions[167] = "Government";
        Institutions[236] = "HomeNet";
        Devices[13] = "iOS";
        Devices[124] = "Windows";
        Devices[87] = "Android";
        Devices[179] = "Tesla ECU";
    }

    function IP(string memory input) public {
        // Convert binary string (length 32) to uint
        bytes memory b = bytes(input);
        uint ipNum = 0;

        for (uint i = 0; i < b.length; i++) {
            ipNum <<= 1; // multiply by 2
            if (b[i] == bytes1(uint8(49))) { // '1' ASCII = 49
                ipNum |= 1;
            }
            // if '0', do nothing
        }

        // Mask for 8 bits: 11111111
        uint mask = 0xFF;

        // Extract each 8-bit segment
        uint countryCode   = (ipNum & (mask << 24)) >> 24;
        uint ispCode       = (ipNum & (mask << 16)) >> 16;
        uint instituteCode = (ipNum & (mask << 8))  >> 8;
        uint deviceCode    = (ipNum & mask);

        // Map codes to labels
        Country   = Countries[countryCode];
        ISP       = ISPs[ispCode];
        Institute = Institutions[instituteCode];
        Device    = Devices[deviceCode];
    }
}
