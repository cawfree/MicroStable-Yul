pragma solidity "0.8.28";

import "@forge-std/Test.sol";
import {Math} from "@openzeppelin-contracts/utils/math/Math.sol";

import {IManager} from "@test/interfaces/IManager.sol";
import {IOracle} from "@test/interfaces/IOracle.sol";
import {IShUSD} from "@test/interfaces/IShUSD.sol";

import {MockERC20} from "@test/mocks/MockERC20.sol";
import {MockOracle} from "@test/mocks/MockOracle.sol";

error InvalidSelector();

interface IInvalid {
    function nonExistentMethod() external;
}

contract MicroStableTest is Test {
    uint256 public constant MIN_COLLAT_RATIO = 1.5e18;

    MockOracle internal oracle;
    MockERC20 internal weth;

    IShUSD internal shUSD;
    IManager internal manager;

    function _bash(string memory cmd) internal returns (bytes memory) {
        string[] memory args = new string[](3);
        args[0] = "bash";
        args[1] = "-c";
        args[2] = cmd;
        return abi.decode(vm.ffi(args), (bytes));
    }

    /// @custom:attribution CodeForcer
    /// @custom:url https://github.com/CodeForcer/foundry-yul/blob/33af9dd7413b05a040af665802678aacff16c98c/test/lib/YulDeployer.sol#L11
    function _deployYulContractByName(
        string memory contractName,
        bytes memory data
    ) internal returns (address deploymentAddress) {
        bytes memory bytecode = _bash(
            string(
                abi.encodePacked(
                    'cast abi-encode "f(bytes)"  "$(echo "$(jq -r \'.bytecode.object\' out/',
                    contractName,
                    ".yul/",
                    contractName,
                    ".json | sed 's/^0x//')\")\""
                )
            )
        );
        bytes memory deploymentCode = abi.encodePacked(bytecode, data);
        assembly {
            deploymentAddress := create(
                0,
                add(deploymentCode, 0x20),
                mload(deploymentCode)
            )
        }
        require(deploymentAddress != address(0), "deployment failed");
    }

    function setUp() external {
        oracle = new MockOracle();
        weth = new MockERC20();
        shUSD = IShUSD(
            _deployYulContractByName(
                "ShUSD",
                abi.encode(address(0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9))
            )
        );
        manager = IManager(
            _deployYulContractByName(
                "Manager",
                abi.encode(address(weth), address(shUSD), address(oracle))
            )
        );

        vm.label(address(oracle), "Oracle");
        vm.label(address(weth), "WETH");
        vm.label(address(shUSD), "ShUSD");
        vm.label(address(manager), "Manager");
    }

    function test_mockOracle() external {
        assertEq(oracle.latestAnswer(), 0);
        oracle.setLatestAnswer(1e8);
        assertEq(oracle.latestAnswer(), 1e8);
    }

    function test_shUSD_manager() external view {
        (bool success, bytes memory data) = address(shUSD).staticcall(
            abi.encodeWithSignature("manager()")
        );
        require(success);
        assertEq(abi.decode(data, (address)), address(manager));
    }

    function test_shUSD_name() external view {
        assertEq(shUSD.name(), "Shafu USD");
    }

    function test_shUSD_symbol() external view {
        assertEq(shUSD.symbol(), "shUSD");
    }

    function test_shUSD_decimals() external view {
        assertEq(shUSD.decimals(), 18);
    }

    function test_shUSD_mint() external {
        assertEq(shUSD.totalSupply(), 0);
        assertEq(shUSD.balanceOf(address(this)), 0);

        vm.expectRevert();
        shUSD.mint(address(this), 1 ether);

        vm.prank(address(manager));
        shUSD.mint(address(this), 1 ether);
        assertEq(shUSD.totalSupply(), 1 ether);
        assertEq(shUSD.balanceOf(address(this)), 1 ether);

        vm.prank(address(manager));
        shUSD.mint(address(this), type(uint256).max - 1 ether);
        assertEq(shUSD.totalSupply(), type(uint256).max);
        assertEq(shUSD.balanceOf(address(this)), type(uint256).max);

        vm.expectRevert();
        shUSD.mint(address(this), 1 wei);

        vm.prank(address(manager));
        shUSD.mint(address(this), 0);
        assertEq(shUSD.totalSupply(), type(uint256).max);
        assertEq(shUSD.balanceOf(address(this)), type(uint256).max);
    }

    function test_shUSD_burn() external {
        assertEq(shUSD.totalSupply(), 0);
        assertEq(shUSD.balanceOf(address(this)), 0);

        vm.expectRevert();
        vm.prank(address(manager));
        shUSD.burn(address(this), 1 wei);

        vm.prank(address(manager));
        shUSD.mint(address(this), 1 ether);
        assertEq(shUSD.balanceOf(address(this)), 1 ether);
        assertEq(shUSD.totalSupply(), 1 ether);

        vm.expectRevert();
        shUSD.burn(address(this), 1 ether);

        vm.prank(address(manager));
        shUSD.burn(address(this), 0 wei);
        assertEq(shUSD.balanceOf(address(this)), 1 ether);
        assertEq(shUSD.totalSupply(), 1 ether);

        vm.expectRevert();
        vm.prank(address(manager));
        shUSD.burn(address(this), 1 ether + 1 wei);

        vm.prank(address(manager));
        shUSD.burn(address(this), 1 ether - 1 wei);
        assertEq(shUSD.balanceOf(address(this)), 1 wei);
        assertEq(shUSD.totalSupply(), 1 wei);

        vm.expectRevert();
        vm.prank(address(manager));
        shUSD.burn(address(1), 1 ether - 1 wei);

        vm.prank(address(manager));
        shUSD.burn(address(this), 1 wei);
        assertEq(shUSD.balanceOf(address(this)), 0);
        assertEq(shUSD.totalSupply(), 0);
    }

    function test_shUSD_transfer() external {
        address c0ffee = address(0xc0ffee);
        address deadbeef = address(0xdeadbeef);

        vm.expectRevert();
        vm.prank(c0ffee);
        shUSD.transfer(deadbeef, 1 wei);

        vm.prank(c0ffee);
        require(shUSD.transfer(deadbeef, 0 wei));

        assertEq(shUSD.balanceOf(c0ffee), 0 wei);
        assertEq(shUSD.balanceOf(deadbeef), 0 wei);

        vm.startPrank(address(manager));
        shUSD.mint(c0ffee, 1 ether);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(c0ffee);
        shUSD.transfer(deadbeef, 1 ether + 1 wei);

        vm.prank(c0ffee);
        require(shUSD.transfer(deadbeef, 0.5 ether));
        assertEq(shUSD.balanceOf(c0ffee), 0.5 ether);
        assertEq(shUSD.balanceOf(deadbeef), 0.5 ether);
        assertEq(shUSD.totalSupply(), 1 ether);

        vm.prank(c0ffee);
        require(shUSD.transfer(deadbeef, 0.5 ether));
        assertEq(shUSD.balanceOf(c0ffee), 0 ether);
        assertEq(shUSD.balanceOf(deadbeef), 1.0 ether);
        assertEq(shUSD.totalSupply(), 1 ether);
    }

    function test_shUSD_allowance() external {
        address c0ffee = address(0xc0ffee);
        address deadbeef = address(0xdeadbeef);

        assertEq(shUSD.allowance(c0ffee, deadbeef), 0);
        assertEq(shUSD.allowance(deadbeef, c0ffee), 0);

        vm.prank(c0ffee);
        require(shUSD.approve(deadbeef, type(uint256).max));
        assertEq(shUSD.allowance(c0ffee, deadbeef), type(uint256).max);

        vm.prank(c0ffee);
        require(shUSD.approve(deadbeef, 0));
        assertEq(shUSD.allowance(c0ffee, deadbeef), 0);

        vm.prank(deadbeef);
        require(shUSD.approve(c0ffee, 1 ether));
        assertEq(shUSD.allowance(deadbeef, c0ffee), 1 ether);

        vm.prank(deadbeef);
        require(shUSD.approve(c0ffee, 1 ether));
        assertEq(shUSD.allowance(deadbeef, c0ffee), 1 ether);

        vm.prank(deadbeef);
        require(shUSD.approve(c0ffee, 1.1 ether));
        assertEq(shUSD.allowance(deadbeef, c0ffee), 1.1 ether);

        vm.prank(deadbeef);
        require(shUSD.approve(c0ffee, 0));
        assertEq(shUSD.allowance(deadbeef, c0ffee), 0);
    }

    function test_shUSD_transferFrom() external {
        address c0ffee = address(0xc0ffee);
        address deadbeef = address(0xdeadbeef);
        address babe = address(0xbabe);

        vm.prank(address(manager));
        shUSD.mint(c0ffee, 50 ether);

        assertEq(shUSD.totalSupply(), 50 ether);
        assertEq(shUSD.balanceOf(c0ffee), 50 ether);

        vm.expectRevert();
        vm.prank(deadbeef);
        shUSD.transferFrom(c0ffee, babe, 50 ether);

        vm.prank(c0ffee);
        require(shUSD.approve(deadbeef, type(uint256).max));
        assertEq(shUSD.allowance(c0ffee, deadbeef), type(uint256).max);

        vm.expectRevert();
        vm.prank(deadbeef);
        shUSD.transferFrom(c0ffee, babe, 100 ether);

        vm.prank(deadbeef);
        require(shUSD.transferFrom(c0ffee, babe, 1 ether));
        assertEq(shUSD.balanceOf(c0ffee), 49 ether);
        assertEq(shUSD.balanceOf(deadbeef), 0 ether);
        assertEq(shUSD.balanceOf(babe), 1 ether);
        assertEq(shUSD.allowance(c0ffee, deadbeef), type(uint256).max);
        assertEq(shUSD.totalSupply(), 50 ether);

        vm.prank(c0ffee);
        require(shUSD.approve(babe, 2 ether));

        vm.expectRevert();
        vm.prank(babe);
        shUSD.transferFrom(c0ffee, babe, 3 ether);

        vm.prank(babe);
        require(shUSD.transferFrom(c0ffee, babe, 1 ether));
        vm.assertEq(shUSD.balanceOf(c0ffee), 48 ether);
        vm.assertEq(shUSD.balanceOf(babe), 2 ether);
        vm.assertEq(shUSD.allowance(c0ffee, babe), 1 ether);

        vm.prank(babe);
        require(shUSD.transferFrom(c0ffee, babe, 1 ether));
        vm.assertEq(shUSD.balanceOf(c0ffee), 47 ether);
        vm.assertEq(shUSD.balanceOf(babe), 3 ether);
        vm.assertEq(shUSD.allowance(c0ffee, babe), 0 ether);
    }

    function test_manager_weth() external view {
        assertEq(address(manager.weth()), address(weth));
    }

    function test_manager_shUSD() external view {
        assertEq(address(manager.shUSD()), address(shUSD));
    }

    function test_manager_oracle() external view {
        assertEq(address(manager.oracle()), address(oracle));
    }

    function test_manager_minCollatRatio() external view {
        assertEq(manager.MIN_COLLAT_RATIO(), MIN_COLLAT_RATIO);
    }

    function test_manager_deposit() external {
        address c0ffee = address(0xc0ffee);
        weth.mint(c0ffee, 100 ether);
        vm.startPrank(c0ffee);
        require(weth.approve(address(manager), type(uint256).max));
        assertEq(manager.address2deposit(c0ffee), 0);
        manager.deposit(50 ether);
        assertEq(weth.balanceOf(c0ffee), 50 ether);
        assertEq(weth.balanceOf(address(manager)), 50 ether);
        assertEq(manager.address2deposit(c0ffee), 50 ether);
        manager.deposit(50 ether);
        assertEq(weth.balanceOf(c0ffee), 0 ether);
        assertEq(weth.balanceOf(address(manager)), 100 ether);
        assertEq(manager.address2deposit(c0ffee), 100 ether);
    }

    function test_manager_collatRatio() external view {
        address c0ffee = address(0xc0ffee);
        assertEq(manager.collatRatio(c0ffee), type(uint256).max);
    }

    // @custom:url https://github.com/shafu0x/MicroStable/blob/95685925f75c502cc93a4d3aa040782d57d2df96/src/MicroStable.sol#L72C5-L73C32
    function _ratio(
        uint256 minted,
        uint256 deposit
    ) internal view returns (uint256) {
        if (minted == 0) return type(uint256).max;
        uint256 totalValue = (deposit * (oracle.latestAnswer() * 1e10)) / 1e18;
        return totalValue / minted;
    }

    function _requiredDeposit(uint256 minted) internal view returns (uint256) {
        return
            Math.mulDiv(
                MIN_COLLAT_RATIO * minted,
                1e18,
                (oracle.latestAnswer() * 1e10),
                Math.Rounding.Ceil // avoid marginal rounding errors to ensure solvent deposits
            );
    }

    function _isSolvent(
        uint256 minted,
        uint256 deposit
    ) internal view returns (bool) {
        return _ratio(minted, deposit) >= MIN_COLLAT_RATIO;
    }

    function testFuzz_manager_mint(
        uint256 minted,
        uint256 deposit,
        uint256 latestAnswer
    ) external {
        address c0ffee = address(0xc0ffee);

        minted = bound(minted, 0, type(uint128).max);
        deposit = bound(deposit, 0, type(uint128).max);
        oracle.setLatestAnswer(bound(latestAnswer, 1e3, 1e14));

        vm.startPrank(c0ffee);
        weth.mint(c0ffee, deposit);
        weth.approve(address(manager), deposit);
        manager.deposit(deposit);

        if (_isSolvent(minted, deposit)) {
            manager.mint(minted);
            assertEq(_ratio(minted, deposit), manager.collatRatio(c0ffee));
        } else {
            vm.expectRevert();
            manager.mint(minted);
        }
    }

    function testFuzz_manager_burn(
        uint256 latestAnswer,
        uint256 minted
    ) external {
        address c0ffee = address(0xc0ffee);
        latestAnswer = bound(latestAnswer, 1e5, 1e11);

        minted = bound(minted, 1 ether, 100 ether);
        oracle.setLatestAnswer(latestAnswer);

        uint256 deposit = _requiredDeposit(minted);
        assert(_isSolvent(minted, deposit));

        vm.startPrank(c0ffee);
        weth.mint(c0ffee, deposit);
        weth.approve(address(manager), deposit);
        manager.deposit(deposit);
        manager.mint(minted);
        assertEq(shUSD.balanceOf(c0ffee), minted);
        assertEq(manager.address2minted(c0ffee), minted);

        assertEq(manager.collatRatio(c0ffee), _ratio(minted, deposit));

        uint256 toBurn = minted / 2;
        uint256 expectedRatio = _ratio(minted - toBurn, deposit);

        manager.burn(toBurn);
        assertEq(manager.collatRatio(c0ffee), expectedRatio);
        assertEq(shUSD.balanceOf(c0ffee), minted - toBurn);
        assertEq(manager.address2minted(c0ffee), minted - toBurn);

        manager.burn(minted - toBurn);
        assertEq(manager.collatRatio(c0ffee), type(uint256).max);
        assertEq(shUSD.balanceOf(c0ffee), 0);
        assertEq(manager.address2minted(c0ffee), 0);
    }

    function testFuzz_manager_withdraw(
        uint256 latestAnswer,
        uint256 minted,
        uint256 ratio
    ) external {
        address c0ffee = address(0xc0ffee);
        latestAnswer = bound(latestAnswer, 1e5, 1e11);
        ratio = bound(ratio, 0.1e18, 0.9e18);
        minted = bound(minted, 1 ether, 100 ether);
        oracle.setLatestAnswer(latestAnswer);

        uint256 deposit = _requiredDeposit(minted);
        assert(_isSolvent(minted, deposit));

        vm.startPrank(c0ffee);
        weth.mint(c0ffee, deposit);
        weth.approve(address(manager), deposit);
        manager.deposit(deposit);
        manager.mint(minted);

        uint256 toBurn = (ratio * minted) / 1e18;
        uint256 mustLeaveDeposit = _requiredDeposit(minted - toBurn);

        {
            uint256 mintedBefore = manager.address2minted(c0ffee);
            manager.burn(toBurn);
            assertEq(manager.address2minted(c0ffee), mintedBefore - toBurn);
            manager.withdraw(deposit - mustLeaveDeposit);
            assertEq(weth.balanceOf(c0ffee), deposit - mustLeaveDeposit);
            assertEq(manager.address2deposit(c0ffee), mustLeaveDeposit);
        }

        manager.burn(shUSD.balanceOf(c0ffee));
        manager.withdraw(mustLeaveDeposit);

        assertEq(weth.balanceOf(c0ffee), deposit);
        assertEq(shUSD.balanceOf(c0ffee), 0);
        assertEq(manager.address2minted(c0ffee), 0);
        assertEq(manager.address2deposit(c0ffee), 0);
    }

    function testFuzz_manager_liquidate(
        uint256 latestAnswer,
        uint256 nextAnswer,
        uint256 minted
    ) external {
        address c0ffee = address(0xc0ffee);
        address deadbeef = address(0xdeadbeef);

        latestAnswer = bound(latestAnswer, 1e5, 1e11);
        nextAnswer = bound(nextAnswer, 1e5, 1e11);
        minted = bound(minted, 1 ether, 100 ether);
        oracle.setLatestAnswer(latestAnswer);

        uint256 deposit = _requiredDeposit(minted);
        assert(_isSolvent(minted, deposit));

        vm.startPrank(c0ffee);
        weth.mint(c0ffee, deposit);
        weth.approve(address(manager), deposit);
        manager.deposit(deposit);
        manager.mint(minted);

        vm.startPrank(deadbeef);
        weth.mint(deadbeef, deposit);
        weth.approve(address(manager), deposit);
        manager.deposit(deposit);
        manager.mint(minted);

        oracle.setLatestAnswer(nextAnswer);

        if (_isSolvent(minted, deposit)) {
            vm.expectRevert();
            manager.liquidate(c0ffee);
        } else {
            manager.liquidate(c0ffee);
            assertEq(shUSD.balanceOf(c0ffee), 0);
            assertEq(weth.balanceOf(deadbeef), deposit);
        }
    }

    function test_microStable_unsupportedSelector() external {
        vm.expectRevert(InvalidSelector.selector);
        IInvalid(address(shUSD)).nonExistentMethod();
        vm.expectRevert(InvalidSelector.selector);
        IInvalid(address(manager)).nonExistentMethod();
    }
}
