// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "./IERC165.sol";
import {IReceiver} from "./IReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ReceiverTemplate is IReceiver, Ownable {
  
  address private s_forwarderAddress;
 
  address private s_expectedAuthor; 
  bytes10 private s_expectedWorkflowName; 
  bytes32 private s_expectedWorkflowId; 

  bytes private constant HEX_CHARS = "0123456789abcdef";


  error InvalidForwarderAddress();
  error InvalidSender(address sender, address expected);
  error InvalidAuthor(address received, address expected);
  error InvalidWorkflowName(bytes10 received, bytes10 expected);
  error InvalidWorkflowId(bytes32 received, bytes32 expected);
  error WorkflowNameRequiresAuthorValidation();
  error InvalidMetadata();


  event ForwarderAddressUpdated(address indexed previousForwarder, address indexed newForwarder);
  event ExpectedAuthorUpdated(address indexed previousAuthor, address indexed newAuthor);
  event ExpectedWorkflowNameUpdated(bytes10 indexed previousName, bytes10 indexed newName);
  event ExpectedWorkflowIdUpdated(bytes32 indexed previousId, bytes32 indexed newId);
  event SecurityWarning(string message);

  
  constructor(
    address _forwarderAddress,
    bytes32 _expectedWorkflowId,
    bytes10 _expectedWorkflowName,
    address _expectedAuthor
) Ownable(msg.sender) {
    if (_forwarderAddress == address(0)) {
        revert InvalidForwarderAddress();
    }

    if (_expectedWorkflowId == bytes32(0)) revert InvalidWorkflowId(bytes32(0), _expectedWorkflowId);
    if (_expectedAuthor == address(0)) revert InvalidAuthor(address(0), _expectedAuthor);

    s_forwarderAddress = _forwarderAddress;
    s_expectedWorkflowId = _expectedWorkflowId;
    s_expectedWorkflowName = _expectedWorkflowName;
    s_expectedAuthor = _expectedAuthor;

    emit ForwarderAddressUpdated(address(0), _forwarderAddress);
    emit ExpectedWorkflowIdUpdated(bytes32(0), _expectedWorkflowId);
    emit ExpectedWorkflowNameUpdated(bytes10(0), _expectedWorkflowName);
    emit ExpectedAuthorUpdated(address(0), _expectedAuthor);
}

  function getForwarderAddress() external view returns (address) {
    return s_forwarderAddress;
  }

  
  function getExpectedAuthor() external view returns (address) {
    return s_expectedAuthor;
  }

  function getExpectedWorkflowName() external view returns (bytes10) {
    return s_expectedWorkflowName;
  }

 
  function getExpectedWorkflowId() external view returns (bytes32) {
    return s_expectedWorkflowId;
  }

  
  function onReport(
    bytes calldata metadata,
    bytes calldata report
  ) external override {
    
    if (s_forwarderAddress != address(0) && msg.sender != s_forwarderAddress) {
      revert InvalidSender(msg.sender, s_forwarderAddress);
    }

   
    if (s_expectedWorkflowId != bytes32(0) || s_expectedAuthor != address(0) || s_expectedWorkflowName != bytes10(0)) {
 if (metadata.length != 62 && metadata.length != 64) {
    revert InvalidMetadata();
}


      (bytes32 workflowId, bytes10 workflowName, address workflowOwner) = _decodeMetadata(metadata);

      if (s_expectedWorkflowId != bytes32(0) && workflowId != s_expectedWorkflowId) {
        revert InvalidWorkflowId(workflowId, s_expectedWorkflowId);
      }
      if (s_expectedAuthor != address(0) && workflowOwner != s_expectedAuthor) {
        revert InvalidAuthor(workflowOwner, s_expectedAuthor);
      }

     
      if (s_expectedWorkflowName != bytes10(0)) {
       
        if (s_expectedAuthor == address(0)) {
          revert WorkflowNameRequiresAuthorValidation();
        }
       
        if (workflowName != s_expectedWorkflowName) {
          revert InvalidWorkflowName(workflowName, s_expectedWorkflowName);
        }
      }
    }

    _processReport(report);
  }


  function _bytesToHexString(
    bytes memory data
  ) private pure returns (bytes memory) {
    bytes memory hexString = new bytes(data.length * 2);

    for (uint256 i = 0; i < data.length; i++) {
      hexString[i * 2] = HEX_CHARS[uint8(data[i] >> 4)];
      hexString[i * 2 + 1] = HEX_CHARS[uint8(data[i] & 0x0f)];
    }

    return hexString;
  }

 function _decodeMetadata(
    bytes memory metadata
) internal pure returns (
    bytes32 workflowId,
    bytes10 workflowName,
    address workflowOwner
) {
    if (metadata.length == 62) {
        assembly {
            workflowId := mload(add(metadata, 32))
            workflowName := mload(add(metadata, 64))
            workflowOwner := shr(96, mload(add(metadata, 74)))
        }
    } else if (metadata.length == 64) {
        assembly {
            workflowId := mload(add(metadata, 32))
            workflowName := mload(add(metadata, 64))
            workflowOwner := shr(96, mload(add(metadata, 76)))
        }
    } else {
        revert("Invalid metadata length");
    }

    return (workflowId, workflowName, workflowOwner);
}

  
  function _processReport(
    bytes calldata report
  ) internal virtual;

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual  returns (bool) {
    return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
