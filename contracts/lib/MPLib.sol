// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "../structs/MPStructs.sol"; 


library MPLib { 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


    function transferIn(address _erc20, uint256 _amount, address _self) internal returns (uint256 _balance) {
        if(_erc20 == NATIVE) {
            require(msg.value >= _amount, "contribution mis-match"); 
        }
        else { 
            IERC20 erc20_ = IERC20(_erc20);
            erc20_.transferFrom(msg.sender, _self, _amount); 
        }
        return _self.balance; 
    }


    function getSeconds(Schedule _schedule) pure internal returns (uint256 _seconds){
        _seconds = 60*60*24; 
        if(_schedule == Schedule.DAILY){
            return _seconds;
        }
        _seconds *= 7; 
        if(_schedule == Schedule.WEEKLY){
            return _seconds;
        }
        _seconds *= 4;
        if(_schedule == Schedule.MONTHLY){
            return _seconds;
        }
        _seconds *= 3; 
        if(_schedule == Schedule.QUARTERLY){
             return _seconds;
        }
        return 0; 
    }

    function remove(uint256 [] memory a, uint256 b) pure internal returns (uint256 [] memory c){
        c = new uint256[](a.length-1); 
        uint256 y = 0; 
        for(uint256 x = 0; x < a.length; x++) {
            if(a[x] != b) {
                c[y] = a[x];
            }
        }
        return c; 
    }

}