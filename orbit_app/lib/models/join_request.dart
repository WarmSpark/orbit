class MyRequest {
  final String id;
  final String eventId;
  final String applicantEmail;
  final String status;
  final DateTime createdAt;

  const MyRequest({
    required this.id,
    required this.eventId,
    required this.applicantEmail,
    required this.status,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isDeclined => status == 'declined';

  factory MyRequest.fromJson(Map<String, dynamic> json) => MyRequest(
    id: (json['id'] ?? '').toString(),
    eventId: (json['event_id'] ?? '').toString(),
    applicantEmail: (json['applicant_email'] ?? '') as String,
    status: (json['status'] ?? 'pending') as String,
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
        DateTime.now(),
  );
}
