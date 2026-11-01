import 'escrow_state.dart';
import 'template_type.dart';

/// On-chain escrow snapshot for list and detail screens (amounts in wei).
class EscrowContract {
  const EscrowContract({
    required this.address,
    required this.buyer,
    required this.seller,
    required this.amountWei,
    required this.deadline,
    required this.state,
    required this.createdAt,
    this.templateType = TemplateType.escrow,
  });

  final String address;
  final String buyer;
  final String seller;
  final BigInt amountWei;
  final DateTime deadline;
  final EscrowState state;
  final DateTime createdAt;
  final TemplateType templateType;

  bool get isBuyer => false; // role resolved against connected wallet in UI

  bool isBuyerOf(String? wallet) =>
      wallet != null && wallet.toLowerCase() == buyer.toLowerCase();

  bool isSellerOf(String? wallet) =>
      wallet != null && wallet.toLowerCase() == seller.toLowerCase();

  EscrowContract copyWith({
    String? address,
    String? buyer,
    String? seller,
    BigInt? amountWei,
    DateTime? deadline,
    EscrowState? state,
    DateTime? createdAt,
    TemplateType? templateType,
  }) {
    return EscrowContract(
      address: address ?? this.address,
      buyer: buyer ?? this.buyer,
      seller: seller ?? this.seller,
      amountWei: amountWei ?? this.amountWei,
      deadline: deadline ?? this.deadline,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      templateType: templateType ?? this.templateType,
    );
  }
}

/// Parameters for `factory.createEscrow` (caller becomes buyer).
class CreateEscrowParams {
  const CreateEscrowParams({
    required this.seller,
    required this.amountWei,
    required this.deadline,
  });

  final String seller;
  final BigInt amountWei;
  final DateTime deadline;
}
