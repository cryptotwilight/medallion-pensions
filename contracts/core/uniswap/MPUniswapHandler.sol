// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IVersion.sol"; 
import "../../interfaces/util/IMPTxManager.sol"; 
import "../../interfaces/market/IMPDexHandler.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from  "@openzeppelin/contracts/interfaces/IERC20.sol";

import {PoolKey} from "https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/types/PoolKey.sol";
import {PoolIdLibrary} from "https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/types/PoolId.sol";
import {StateLibrary} from "https://github.com/Uniswap/v4-core/blob/59d3ecf53afa9264a16bba0e38f4c5d2231f80bc/src/libraries/StateLibrary.sol";
import {UniversalRouter} from "https://github.com/Uniswap/universal-router/blob/3663f6db6e2fe121753cd2d899699c2dc75dca86/contracts/UniversalRouter.sol";
import {IPermit2} from "https://github.com/Uniswap/permit2/blob/cc56ad0f3439c502c246fc5cfcc3db92bb8b7219/src/interfaces/IPermit2.sol";


contract UniswapHandler is IMPDexHandler, IVersion { 

    string constant name = "RESERVED_UNISWAP_DEX_HANDLER";
    uint256 constant version = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; 

    using StateLibrary for IPoolManager;

    UniversalRouter public immutable router;

    constructor(address _register, address _router) {
        register = IRegister(_register);
        router = UniversalRouter(_router);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function swap(address _in, uint256 _amountIn, address _out ) payable external returns (uint256 _amountOut){
        PoolKey memory key_ = getKey(_in, _out);
        IOracle oracle_ = IOracle(register.getAddress(ORACLE_CA));
        uint256 inUSD_ = oracle.getPrice(_in); 
        uint256 outUSD_ = oracle.getPrice(_out); 
        (bool ok_, uint256 factor_) = SafeMath.div(inUSD_, outUSD_);
        if(ok_){
            (bool okx_, uint256 minAmountOut_) = SaveMath.mul(_amountIn, factor_ );
            if(okx_){
                _amountOut = swapExactInputSingle(key_, _amountIn, minAmountOut_);
            }
        }
        return _amountOut; 
    }

    //============================================== INTERNAL =======================================================
    function getKey(address _in, address _out) internal returns (PoolKey memory _key) {

        _key = PoolKey ({
                            currency0 : Currency.wrap(_in),
                            currency1 : Currency.wrap(_out),
                            fee : _fee, 
                            tickSpacing : 0,
                            hooks :IHooks(address(0))
                        });
        return _key; 
    }


    function swapExactInputSingle(PoolKey calldata key, uint128 amountIn, uint128 minAmountOut) internal returns (uint256 amountOut) {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute(commands, inputs, deadline);

        // Verify and return the output amount
        amountOut = IERC20(key.currency1).balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");
        return amountOut;
    }
}