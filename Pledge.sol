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

contract PledgeToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    IERC20 public targetToken;
    IUniswapV2Router02 public router;

    address public treasury;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    struct PledgeInfo {
        uint256 amount;
        uint256 period;
        uint256 timestamp;
    }

    mapping(address => PledgeInfo[]) public userPledges;

    event Pledge(
        address indexed user,
        uint256 usdtAmount,
        uint256 treasuryAmount,
        uint256 swapAmount,
        uint256 burnedAmount,
        uint256 period,
        uint256 timestamp
    );

    constructor(
        address _usdt,
        address _targetToken,
        address _router,
        address _treasury
    ) {
        require(
            _usdt != address(0) &&
                _targetToken != address(0) &&
                _router != address(0) &&
                _treasury != address(0),
            "invalid address"
        );

        usdt = IERC20(_usdt);
        targetToken = IERC20(_targetToken);
        router = IUniswapV2Router02(_router);
        treasury = _treasury;
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero address");
        treasury = _treasury;
    }

    function pledge(uint256 amount, uint256 period) external {
        require(amount >= 100 * 1e18, "Minimum pledge amount 100");
        require(period > 0, "invalid period");

        // 拉取 USDT
        usdt.safeTransferFrom(msg.sender, address(this), amount);

        // 50 / 50
        uint256 half = amount / 2;
        uint256 swapAmount = amount - half;

        // 转给项目方
        usdt.safeTransfer(treasury, half);

        // 授权 router
        usdt.safeApprove(address(router), 0);
        usdt.safeApprove(address(router), swapAmount);

        // swap 路径
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(targetToken);

        uint256[] memory expected = router.getAmountsOut(swapAmount, path);
        uint256 minOut = (expected[1] * 95) / 100;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            minOut,
            path,
            address(this),
            block.timestamp + 600
        );

        uint256 received = amounts[1];

        // 销毁
        targetToken.safeTransfer(DEAD, received);

        // 记录质押
        userPledges[msg.sender].push(
            PledgeInfo({
                amount: amount,
                period: period,
                timestamp: block.timestamp
            })
        );

        emit Pledge(
            msg.sender,
            amount,
            half,
            swapAmount,
            received,
            period,
            block.timestamp
        );
    }

    function rescueToken(
        address _token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "zero address");

        IERC20 t = IERC20(_token);
        uint256 bal = t.balanceOf(address(this));
        uint256 out = amount == 0 ? bal : amount;

        require(bal >= out, "insufficient");

        t.safeTransfer(to, out);
    }
}
