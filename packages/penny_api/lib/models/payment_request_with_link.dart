import 'package:meta/meta.dart';
import 'package:penny_api/messages/payment_request.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class PaymentRequestWithLink {
  const PaymentRequestWithLink({required this.request, this.link});

  /// Converts a `Map<String, dynamic>` to a [PaymentRequestWithLink].
  factory PaymentRequestWithLink.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRequestWithLink',
      json,
      () => PaymentRequestWithLink(
        request: PaymentRequest.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
        link: json['link'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRequestWithLink? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequestWithLink.fromJson(json);
  }

  final PaymentRequest request;

  /// The payment page. Shown only now; Penny keeps a hash of it.
  final String? link;

  /// Converts a [PaymentRequestWithLink] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'request': request.toJson(), 'link': ?link};
  }

  @override
  int get hashCode => Object.hashAll([request, link]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequestWithLink &&
        request == other.request &&
        link == other.link;
  }
}
