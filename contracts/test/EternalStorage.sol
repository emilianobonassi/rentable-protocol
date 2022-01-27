// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract EternalStorage {
    /* ========== DATA TYPES ========== */
    mapping(bytes32 => uint256) internal UIntStorage;
    mapping(bytes32 => string) internal StringStorage;
    mapping(bytes32 => address) internal AddressStorage;
    mapping(bytes32 => bytes) internal BytesStorage;
    mapping(bytes32 => bytes32) internal Bytes32Storage;
    mapping(bytes32 => bool) internal BooleanStorage;
    mapping(bytes32 => int256) internal IntStorage;

    // UIntStorage;
    function getUIntValue(bytes32 record) external view returns (uint256) {
        return UIntStorage[record];
    }

    function setUIntValue(bytes32 record, uint256 value) external {
        UIntStorage[record] = value;
    }

    function deleteUIntValue(bytes32 record) external {
        delete UIntStorage[record];
    }

    // StringStorage
    function getStringValue(bytes32 record)
        external
        view
        returns (string memory)
    {
        return StringStorage[record];
    }

    function setStringValue(bytes32 record, string calldata value) external {
        StringStorage[record] = value;
    }

    function deleteStringValue(bytes32 record) external {
        delete StringStorage[record];
    }

    // AddressStorage
    function getAddressValue(bytes32 record) external view returns (address) {
        return AddressStorage[record];
    }

    function setAddressValue(bytes32 record, address value) external {
        AddressStorage[record] = value;
    }

    function deleteAddressValue(bytes32 record) external {
        delete AddressStorage[record];
    }

    // BytesStorage
    function getBytesValue(bytes32 record)
        external
        view
        returns (bytes memory)
    {
        return BytesStorage[record];
    }

    function setBytesValue(bytes32 record, bytes calldata value) external {
        BytesStorage[record] = value;
    }

    function deleteBytesValue(bytes32 record) external {
        delete BytesStorage[record];
    }

    // Bytes32Storage
    function getBytes32Value(bytes32 record) external view returns (bytes32) {
        return Bytes32Storage[record];
    }

    function setBytes32Value(bytes32 record, bytes32 value) external {
        Bytes32Storage[record] = value;
    }

    function deleteBytes32Value(bytes32 record) external {
        delete Bytes32Storage[record];
    }

    // BooleanStorage
    function getBooleanValue(bytes32 record) external view returns (bool) {
        return BooleanStorage[record];
    }

    function setBooleanValue(bytes32 record, bool value) external {
        BooleanStorage[record] = value;
    }

    function deleteBooleanValue(bytes32 record) external {
        delete BooleanStorage[record];
    }

    // IntStorage
    function getIntValue(bytes32 record) external view returns (int256) {
        return IntStorage[record];
    }

    function setIntValue(bytes32 record, int256 value) external {
        IntStorage[record] = value;
    }

    function deleteIntValue(bytes32 record) external {
        delete IntStorage[record];
    }
}
