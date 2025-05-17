// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/market/IMPOracle.sol"; 
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";


contract ChainlinkHandler is IMPOracle, IVersion { 

    string constant name = "RESERVED_CHAINLINK_ORACLE_HANDLER";
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    IRegister register; 
    address self; 

    constructor(address _register) {
        register = IRegister(_register); 
        self = address(this);
    }
    
    function getPrice(address _base) external returns (uint256 _price){


    }

    //==================================== INTERNAL ==============================================================


}