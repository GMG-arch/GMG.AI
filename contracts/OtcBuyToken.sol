// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract OtcBuyToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20 public usdt;
    IUniswapV2Router02 public router;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    event BuyAndBurn(
        address indexed user,
        uint256 usdtAmount,
        uint256 burnedTokenAmount,
        string bizId
    );

    constructor(address _token, address _usdt, address _router) {
        token = IERC20(_token);
        usdt = IERC20(_usdt);
        router = IUniswapV2Router02(_router);
    }

    function buyAndBurn(uint256 amount, string calldata bizId) external {
        require(amount > 0, "amount=0");
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        usdt.safeApprove(address(router), 0);
        usdt.safeApprove(address(router), amount);

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(token);

        uint256 beforeBalance = token.balanceOf(address(this));
        uint256[] memory expected = router.getAmountsOut(amount, path);
        uint256 minOut = (expected[1] * 95) / 100;

        router.swapExactTokensForTokens(
            amount,
            minOut,
            path,
            address(this),
            block.timestamp
        );

        uint256 afterBalance = token.balanceOf(address(this));
        uint256 received = afterBalance - beforeBalance;

        require(received > 0, "no token");
        token.safeTransfer(DEAD, received);

        emit BuyAndBurn(msg.sender, amount, received, bizId);
    }
}
