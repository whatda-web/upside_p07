// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    UpgradeableBeacon
} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {
    BeaconProxy
} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {BeaconBoxV1} from "../src/beacon/BeaconBoxV1.sol";
import {BeaconBoxV2} from "../src/beacon/BeaconBoxV2.sol";

interface Vm {
    function prank(address) external;
    function prank(address msgSender, address txOrigin) external;
}

/// @notice Instructor solution for the student-facing Beacon practice test.
contract BeaconAnswerTest {
    Vm internal constant VM =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant ATTACKER = address(0xBEEF);
    uint256 internal constant INITIAL_VALUE = 1;
    uint256 internal constant VALUE_A = 11;
    uint256 internal constant VALUE_B = 22;

    function testBeaconUpgradeFlow() external {
        BeaconBoxV1 implV1 = new BeaconBoxV1();
        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implV1),
            address(this)
        );

        bytes memory initData = _buildInitData();
        BeaconProxy p1 = new BeaconProxy(address(beacon), initData);
        BeaconProxy p2 = new BeaconProxy(address(beacon), initData);

        BeaconBoxV1 b1 = BeaconBoxV1(address(p1));
        BeaconBoxV1 b2 = BeaconBoxV1(address(p2));

        _assertInitialized(b1, b2);
        _assertReinitializeFails(p1, p2);
        _setIndependentStateAsOwner(b1, b2);

        BeaconBoxV2 implV2 = new BeaconBoxV2();
        _assertAttackerCannotUpgrade(beacon, implV2);
        _upgradeAsOwner(beacon, implV2);

        BeaconBoxV2 b1v2 = BeaconBoxV2(address(p1));
        BeaconBoxV2 b2v2 = BeaconBoxV2(address(p2));

        _assertUpgradePropagation(b1v2, b2v2);
        _assertIncrementPaths(b1v2, b2v2);
    }

    function _buildInitData() internal view returns (bytes memory) {
        return
            abi.encodeCall(
                BeaconBoxV1.initialize,
                (INITIAL_VALUE, address(this))
            );
    }

    function _assertInitialized(BeaconBoxV1 b1, BeaconBoxV1 b2) internal view {
        require(b1.value() == INITIAL_VALUE, "proxy A init failed");
        require(b2.value() == INITIAL_VALUE, "proxy B init failed");
    }

    function _assertReinitializeFails(BeaconProxy p1, BeaconProxy p2) internal {
        (bool ok1, ) = address(p1).call(
            abi.encodeCall(BeaconBoxV1.initialize, (999, address(this)))
        );
        (bool ok2, ) = address(p2).call(
            abi.encodeCall(BeaconBoxV1.initialize, (999, address(this)))
        );

        require(!ok1, "proxy A reinitialize should fail");
        require(!ok2, "proxy B reinitialize should fail");
    }

    function _setIndependentStateAsOwner(
        BeaconBoxV1 b1,
        BeaconBoxV1 b2
    ) internal {
        b1.setValue(VALUE_A);
        b2.setValue(VALUE_B);

        require(b1.value() == VALUE_A, "proxy A owner setValue failed");
        require(b2.value() == VALUE_B, "proxy B owner setValue failed");
    }

    function _assertAttackerCannotUpgrade(
        UpgradeableBeacon beacon,
        BeaconBoxV2 implV2
    ) internal {
        VM.prank(ATTACKER, ATTACKER);
        (bool ok, ) = address(beacon).call(
            abi.encodeWithSelector(beacon.upgradeTo.selector, address(implV2))
        );
        require(!ok, "unauthorized beacon upgrade should fail");
    }

    function _upgradeAsOwner(
        UpgradeableBeacon beacon,
        BeaconBoxV2 implV2
    ) internal {
        beacon.upgradeTo(address(implV2));
    }

    function _assertUpgradePropagation(
        BeaconBoxV2 b1v2,
        BeaconBoxV2 b2v2
    ) internal view {
        require(b1v2.version() == 2, "proxy A version mismatch");
        require(b2v2.version() == 2, "proxy B version mismatch");
        require(b1v2.value() == VALUE_A, "proxy A state not preserved");
        require(b2v2.value() == VALUE_B, "proxy B state not preserved");
    }

    function _assertIncrementPaths(
        BeaconBoxV2 b1v2,
        BeaconBoxV2 b2v2
    ) internal {
        b1v2.increment();
        b2v2.increment();

        require(b1v2.value() == VALUE_A + 1, "proxy A increment failed");
        require(b2v2.value() == VALUE_B + 1, "proxy B increment failed");
    }
}
