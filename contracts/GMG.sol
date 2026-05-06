// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniSwapRouter02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}
interface IUniSwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}
interface IUniSwapRouter {
    function factory() external pure returns (address);
}
contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, type(uint256).max);
    }
}
library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: APPROVE_FAILED"
        );
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }

    function safeTransferBNB(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: BNB_TRANSFER_FAILED");
    }
}
contract GMG is ERC20, Ownable {
    uint256 private constant MAX_SUPPLY = 1_000_000_000 * 1e18;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 public sellFee = 300;
    uint256 public buyFee = 0;
    uint256 public swapSlippage = 9500;

    address public feeReceiver;
    address public defiRouter;
    address public pair;
    address public lp;
    address public distributor;

    bool public buyEnabled = false;
    bool public sellEnabled = false;

    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public isSwapPair;

    constructor(
        address _feeReceiver,
        address _defiRouter,
        address _pair
    ) ERC20("GMG", "GMG") {
        require(_feeReceiver != address(0), "Invalid fee receiver");
        _mint(msg.sender, MAX_SUPPLY);
        feeReceiver = _feeReceiver;
        defiRouter = _defiRouter;
        pair = _pair;

        whitelist[msg.sender] = true;
        whitelist[address(this)] = true;
        distributor = address(new TokenDistributor(pair));

        IUniSwapFactory swapFactory = IUniSwapFactory(
            IUniSwapRouter(defiRouter).factory()
        );
        lp = swapFactory.createPair(address(this), pair);
        isSwapPair[lp] = true;
    }

    function setBuyEnabled(bool enabled) external onlyOwner {
        buyEnabled = enabled;
    }

    function setSellEnabled(bool enabled) external onlyOwner {
        sellEnabled = enabled;
    }

    function setSwapPair(address _swapPair, bool enabled) external onlyOwner {
        isSwapPair[_swapPair] = enabled;
    }

    function setFeeReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid address");
        feeReceiver = _receiver;
    }

    function setSwapSlippage(uint256 _swapSlippage) external onlyOwner {
        swapSlippage = _swapSlippage;
    }

    function setBuyFee(uint256 _buyFee) external onlyOwner {
        buyFee = _buyFee;
    }

    function setSellFee(uint256 _sellFee) external onlyOwner {
        sellFee = _sellFee;
    }

    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
        }
    }
    function addToBlacklist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            blacklist[accounts[i]] = true;
        }
    }

    function removeFromWhitelist(
        address[] calldata accounts
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = false;
        }
    }

    function removeFromBlacklist(
        address[] calldata accounts
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            blacklist[accounts[i]] = false;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!blacklist[from] && !blacklist[to], "Blacklisted");

        bool isBuy = isSwapPair[from];
        bool isSell = isSwapPair[to];

        if (isBuy && !whitelist[to]) {
            require(buyEnabled, "Buy disabled");
        }
        if (isSell && !whitelist[from]) {
            require(sellEnabled, "Sell disabled");
        }

        if (!whitelist[from] && isSell && sellFee > 0) {
            uint256 feeAmount = (amount * sellFee) / FEE_DENOMINATOR;
            amount -= feeAmount;

            super._transfer(from, address(this), feeAmount);
            uint256[] memory swapRes = _swap(address(this), pair, feeAmount);
            TransferHelper.safeTransferFrom(
                pair,
                distributor,
                feeReceiver,
                swapRes[1]
            );
        }

        if (!whitelist[to] && isBuy && buyFee > 0) {
            uint256 feeAmount = (amount * buyFee) / FEE_DENOMINATOR;
            amount -= feeAmount;

            super._transfer(from, feeReceiver, feeAmount);
        }

        super._transfer(from, to, amount);
    }

    function _swap(
        address tokenA,
        address tokenB,
        uint256 tokenAAmount
    ) internal returns (uint256[] memory amounts) {
        TransferHelper.safeApprove(tokenA, defiRouter, tokenAAmount);

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256[] memory paramAmounts = getAmountsOut(tokenAAmount, path);

        amounts = IUniSwapRouter02(defiRouter).swapExactTokensForTokens(
            tokenAAmount,
            (paramAmounts[1] * swapSlippage) / FEE_DENOMINATOR,
            path,
            distributor,
            block.timestamp + 1 minutes
        );
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        amounts = IUniSwapRouter02(defiRouter).getAmountsOut(amountIn, path);
    }
}
