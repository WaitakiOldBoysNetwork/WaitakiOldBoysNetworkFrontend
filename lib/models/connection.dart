import 'profile.dart';

enum ConnectionStatus {
  pending,
  accepted,
  rejected,
  none;

  static ConnectionStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return ConnectionStatus.accepted;
      case 'rejected':
        return ConnectionStatus.rejected;
      case 'pending':
        return ConnectionStatus.pending;
      default:
        return ConnectionStatus.none;
    }
  }

  String toDbString() {
    return name;
  }
}

class Connection {
  final String id;
  final String requesterId;
  final String recipientId;
  final ConnectionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Profile? requester;
  final Profile? recipient;

  Connection({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.requester,
    this.recipient,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    Profile? reqProfile;
    Profile? recProfile;

    if (json['requester'] is Map<String, dynamic>) {
      reqProfile = Profile.fromJson(json['requester'] as Map<String, dynamic>);
    }
    if (json['recipient'] is Map<String, dynamic>) {
      recProfile = Profile.fromJson(json['recipient'] as Map<String, dynamic>);
    }

    return Connection(
      id: json['id']?.toString() ?? '',
      requesterId: json['requester_id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      status: ConnectionStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      requester: reqProfile,
      recipient: recProfile,
    );
  }
}
