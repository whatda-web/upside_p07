// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSBoxV1} from "../src/uups/UUPSBoxV1.sol";
import {UUPSBoxV2} from "../src/uups/UUPSBoxV2.sol";

interface Vm {
    function prank(address) external;
    function prank(address msgSender, address txOrigin) external;
}

/// @notice Instructor solution for the student-facing UUPS practice test.
contract UUPSAnswerTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant ATTACKER = address(0xBEEF);
    uint256 internal constant INITIAL_VALUE = 10;
    uint256 internal constant UPDATED_VALUE = 42;

    function testUUPSUpgradeFlow() external {
        UUPSBoxV1 implV1 = new UUPSBoxV1();

        bytes memory initData = _buildInitData();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implV1), initData);

        UUPSBoxV1 boxV1 = UUPSBoxV1(address(proxy));
        _assertInitialized(boxV1);

        _assertReinitializeFails(proxy);
        _setValueAsOwner(boxV1);

        UUPSBoxV2 implV2 = new UUPSBoxV2();
        _assertAttackerCannotUpgrade(proxy, boxV1, implV2);

        _upgradeAsOwner(boxV1, implV2);

        UUPSBoxV2 boxV2 = UUPSBoxV2(address(proxy));
        _assertUpgradeState(boxV2);
        _assertIncrement(boxV2);
    }

    function _buildInitData() internal view returns (bytes memory) {
        return abi.encodeCall(UUPSBoxV1.initialize, (INITIAL_VALUE, address(this)));
    }

    function _assertInitialized(UUPSBoxV1 boxV1) internal view {
        require(boxV1.value() == INITIAL_VALUE, "init failed");
    }

    function _assertReinitializeFails(ERC1967Proxy proxy) internal {
        (bool ok,) = address(proxy).call(
            abi.encodeCall(UUPSBoxV1.initialize, (999, address(this)))
        );
        require(!ok, "reinitialize should fail");
    }

    function _setValueAsOwner(UUPSBoxV1 boxV1) internal {
        VM.prank(ATTACKER, ATTACKER);
        (bool ok,) = address(boxV1).call(abi.encodeCall(UUPSBoxV1.setValue, (UPDATED_VALUE)));
        require(!ok, "attacker setValue should fail");

        boxV1.setValue(UPDATED_VALUE);
        require(boxV1.value() == UPDATED_VALUE, "owner setValue failed");
    }

    function _assertAttackerCannotUpgrade(
        ERC1967Proxy proxy,
        UUPSBoxV1 boxV1,
        UUPSBoxV2 implV2
    ) internal {
        VM.prank(ATTACKER, ATTACKER);
        (bool ok,) = address(proxy).call(
            abi.encodeWithSelector(boxV1.upgradeToAndCall.selector, address(implV2), bytes(""))
        );
        require(!ok, "unauthorized upgrade should fail");
    }

    function _upgradeAsOwner(UUPSBoxV1 boxV1, UUPSBoxV2 implV2) internal {
        boxV1.upgradeToAndCall(address(implV2), bytes(""));
    }

    function _assertUpgradeState(UUPSBoxV2 boxV2) internal view {
        require(boxV2.version() == 2, "version mismatch");
        require(boxV2.value() == UPDATED_VALUE, "state not preserved");
    }

    function _assertIncrement(UUPSBoxV2 boxV2) internal {
        boxV2.increment();
        require(boxV2.value() == UPDATED_VALUE + 1, "increment failed");
    }
}
