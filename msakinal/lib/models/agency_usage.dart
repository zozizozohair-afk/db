class AgencyUsage {
  final String agencyId;
  final String contractId;
  final String contractType;
  final DateTime usageDate;
  final String usageDetails;

  AgencyUsage({
    required this.agencyId,
    required this.contractId,
    required this.contractType,
    required this.usageDate,
    required this.usageDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'agencyId': agencyId,
      'contractId': contractId,
      'contractType': contractType,
      'usageDate': usageDate,
      'usageDetails': usageDetails,
    };
  }

  static AgencyUsage fromMap(Map<String, dynamic> map) {
    return AgencyUsage(
      agencyId: map['agencyId'],
      contractId: map['contractId'],
      contractType: map['contractType'],
      usageDate: map['usageDate'].toDate(),
      usageDetails: map['usageDetails'],
    );
  }
}
