//SPDX-License-Identifier: Frensware
pragma solidity ^0.8.21;
pragma abicoder v2;
//import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
//import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

interface IERC20 {
	function totalSupply() external view returns (uint);
	function balanceOf(address account) external view returns (uint);
	function transfer(address recipient, uint amount) external returns (bool);
	function allowance(address owner, address spender) external view returns (uint);
	function approve(address spender, uint amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint amount) external returns (bool);
	event Transfer(address indexed from, address indexed to, uint value);
	event Approval(address indexed owner, address indexed spender, uint value);
}


interface IDODO {
    // Dodo flashloan interface, we need this to initate the flash loan.
    function flashLoan(
        uint256 baseAmount,
        uint256 quoteAmount,
        address assetTo,
        bytes calldata data
    ) external;

    function _BASE_TOKEN_() external view returns (address);
}


interface IUniswapV2Router {
    // Uniswap v2 interface, allows us to call uniswap v2 fork routers
    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    // uniswap v2 pair interface, allows us to query token pairs (ie liquidity pools)
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112, uint112, uint32);
}

contract doughDough  {
    /* The start of the arbitrage contract,
    as this file was flattened to make easier to
    publish source.
    */
    address immutable owner;
    string public ERR_NO_PROFIT  = "Trade Reverted, No Profit Made";
    bool debug = false;
    address thisAddress;


    constructor() {
        owner = payable(msg.sender);
        thisAddress = address(this);
    }

    modifier axx {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    modifier callbackAxx {
        require(tx.origin == owner, "Origin is not owner");
        _;
    }

    modifier profitOnly(address _token1) {
        if(!debug){
            uint startBalance = tokenBalance(_token1);
            _;
            uint endBalance = tokenBalance(_token1);
            require(endBalance > startBalance, ERR_NO_PROFIT);
        }
    }

    function setDebug(bool enabled) external axx{
        debug = enabled;
    }

    function tokenBalance(address _tokenAddress) private view returns(uint256){
        return IERC20(_tokenAddress).balanceOf(thisAddress);
    }

    function _dualDexTrade(
        address _router1, 
        address _router2, 
        address _token1, 
        address _token2, 
        uint256 _amount) 
        internal profitOnly(_token1) {
        
        uint token2InitialBalance = tokenBalance(_token2);
        swap(_router1,_token1, _token2,_amount);
        uint token2Balance = IERC20(_token2).balanceOf(thisAddress);
        uint tradeableAmount = token2Balance - token2InitialBalance;
        swap(_router2,_token2, _token1,tradeableAmount);
        
        }

    function _triDexTrade(
        address _router1, 
        address _router2, 
        address _router3,
        address _token1, 
        address _token2, 
        address _token3, 
        uint256 _amount
        ) internal profitOnly(_token1) {
        
        uint token2InitialBalance = tokenBalance(_token2);
        uint token3InitialBalance = tokenBalance(_token3);
        swap(_router1, _token1, _token2, _amount);
        uint token2Balance = tokenBalance(_token2);
        uint tradeableAmount = token2Balance - token2InitialBalance;
        swap(_router2, _token2, _token3, tradeableAmount);
        uint token3Balance = tokenBalance(_token3);
        uint tradeableAmount_token3 = token3Balance - token3InitialBalance;
        swap(_router3, _token3, _token1, tradeableAmount_token3);
        
        
    }

    function dualDexTrade(
        address _router1, 
        address _router2, 
        address _token1, 
        address _token2, 
        uint256 _amount) external callbackAxx {
            _dualDexTrade(_router1, _router2, _token1, _token2, _amount);
        }

    function triDexTrade(
        address _router1, 
        address _router2, 
        address _router3,
        address _token1, 
        address _token2, 
        address _token3, 
        uint256 _amount) external callbackAxx {
            _triDexTrade(_router1, _router2, _router3, _token1, _token2, _token3, _amount);
        }

    function swap(address router, address _tokenIn, address _tokenOut, uint256 _amount) private {
        /*Swap function for our dual and tri dex trades*/
        IERC20(_tokenIn).approve(router, _amount);
        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        uint deadline = block.timestamp + 300;
        IUniswapV2Router(router).swapExactTokensForTokens(_amount, 1, path, address(this), deadline);
    }

    function getAmountOutMin(address router, address _tokenIn, address _tokenOut, uint256 _amount) public view returns (uint256) {
        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        uint256[] memory amountOutMins = IUniswapV2Router(router).getAmountsOut(_amount, path);
        return amountOutMins[path.length - 1];
    }

    function getAmountInMin(address router, address _tokenIn, address _tokenOut, uint256 _amount) public view returns (uint256[] memory) {
        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        uint256[] memory amountInMins = IUniswapV2Router(router).getAmountsIn(_amount, path);
        return amountInMins;
    }

    function estimateDualDexTrade(
        address _router1, 
        address _router2, 
        address _token1, 
        address _token2, 
        uint256 _amount
        ) external view returns (uint256) {
        uint256 amtBack1 = getAmountOutMin(_router1, _token1, _token2, _amount);
        uint256 amtBack2 = getAmountOutMin(_router2, _token2, _token1, amtBack1);
        return amtBack2;
    }
    function estimateTriDexTrade(
        address _router1, 
        address _router2, 
        address _router3, 
        address _token1, 
        address _token2, 
        address _token3, 
        uint256 _amount
        ) external view returns (uint256) {
        uint amtBack1 = getAmountOutMin(_router1, _token1, _token2, _amount);
        uint amtBack2 = getAmountOutMin(_router2, _token2, _token3, amtBack1);
        uint amtBack3 = getAmountOutMin(_router3, _token3, _token1, amtBack2);
        return amtBack3;
    }

    
    function executeCall(
        /*
            @dev: Function to execute a transaction with arbitrary parameters. Handles 
            all withdrawals, etc. Can be used for token transfers, eth transfers, 
            or anything else.
        */
        address r,
        uint256 v,
        bytes memory d
        ) private {
       /*
         @dev: Gas efficient arbitrary call in assembly.
       */
        assembly {
            let success_ := call(gas(), r, v, add(d, 0x00), mload(d), 0x20, 0x0)
            let success := eq(success_, 0x1)
            if iszero(success) {
                revert(mload(d), add(d, 0x20))
            }
        }
    }

    function ethBalance() private view returns(uint256) {
        uint128 self;
        assembly {
            self :=selfbalance()
        }
        return self;
    }

    function recoverEth() external axx {
        executeCall(msg.sender, ethBalance(), "");
    }

    function recoverTokens(address tokenAddress) external axx {
        IERC20(tokenAddress).transfer(msg.sender, tokenBalance(tokenAddress));
    }

    receive() external payable {}

    function dodoFlashLoan(
    /* We call this function to initiate a flash loan.
     It encodes our arguments and sends them to the dodo pool.
     They then calculate and make sure they are not loosing money,
     then they send the requested funds to our contract.
     We then complete the trade and pay it back. */


        address flashLoanPool, //You will make a flashloan from this DODOV2 pool
        address token1,
        address token2,
        address token3,
        address _router1,
        address _router2,
        address _router3,
        uint256 loanAmount
    ) external axx {
        //Note: The data can be structured with any variables required by your logic. The following code is just an example
        bytes memory data = abi.encode(flashLoanPool, token1, token2, token3, _router1, _router2, _router3, loanAmount);
        address flashLoanBase = IDODO(flashLoanPool)._BASE_TOKEN_();
        if (flashLoanBase == token1) {
            IDODO(flashLoanPool).flashLoan(loanAmount, 0, address(this), data);
        } else {
            IDODO(flashLoanPool).flashLoan(0, loanAmount, address(this), data);
        }
    }

    //Note: CallBack function executed by DODOV2(DVM) flashLoan pool
    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        _flashLoanCallBack(sender, baseAmount, quoteAmount, data);
    }

    //Note: CallBack function executed by DODOV2(DPP) flashLoan pool
    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        _flashLoanCallBack(sender, baseAmount, quoteAmount, data);
    }

    //Note: CallBack function executed by DODOV2(DSP) flashLoan pool
    function DSPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        _flashLoanCallBack(sender, baseAmount, quoteAmount, data);
    }

    function _flashLoanCallBack(
        address sender, 
        uint256, 
        uint256, 
        bytes calldata data
        ) internal {
        (address flashLoanPool, 
        address token1, 
        address token2, 
        address token3, 
        address _router1, 
        address _router2, 
        address _router3, 
        uint256 amount) = abi.decode(data, (address, address, address, address, address, address, address, uint256));
        require(sender == address(this) && msg.sender == flashLoanPool, "HANDLE_FLASH_NENIED");
        //this.dualDexTrade(_router1, _router2, token1, token2, amount);
        // To do a dual trade with flash loan, send
        // 0x000000000000000000000000000000000000000F as parameter for token3 and router3
        if (token3 == address(0x000000000000000000000000000000000000000F)) {
            _dualDexTrade(_router1, _router2, token1, token2, amount);
        }else{
            _triDexTrade(_router1, _router2, _router3, token1, token2, token3, amount);}
        IERC20(token1).transfer(flashLoanPool, amount);
    }

    function killSelf() public payable axx {
        // destroy contract -- warning, cannot undo this
        address payable addr = payable(address(owner));
        selfdestruct(addr);
    }


}
