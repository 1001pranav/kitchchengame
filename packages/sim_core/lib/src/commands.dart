/// Player commands (doc 03 §3). The only way state changes besides tick/beginDay/endDay.
sealed class Command {
  const Command();
}

class BuyDueDiligence extends Command {
  final int offerIndex;
  const BuyDueDiligence(this.offerIndex);
}

class BuyRestaurant extends Command {
  final int offerIndex;
  const BuyRestaurant(this.offerIndex);
}

class SetDayOff extends Command {
  final int staffId, weekday;
  const SetDayOff(this.staffId, this.weekday);
}

class WorkDayOff extends Command {
  final int staffId;
  const WorkDayOff(this.staffId);
}

class PlaceOrder extends Command {
  final String supplierId;
  final Map<String, int> lines;
  const PlaceOrder(this.supplierId, this.lines);
}

class CancelOrder extends Command {
  final int orderId;
  const CancelOrder(this.orderId);
}

class SetPrice extends Command {
  final String dishId;
  final int price;
  const SetPrice(this.dishId, this.price);
}

class SetDishEnabled extends Command {
  final String dishId;
  final bool enabled;
  const SetDishEnabled(this.dishId, this.enabled);
}

class Hire extends Command {
  final int applicantId;
  const Hire(this.applicantId);
}

class Fire extends Command {
  final int staffId;
  const Fire(this.staffId);
}

class SetWage extends Command {
  final int staffId, wage;
  const SetWage(this.staffId, this.wage);
}

class Train extends Command {
  final int staffId;
  const Train(this.staffId);
}

class GiveDayOff extends Command {
  final int staffId;
  const GiveDayOff(this.staffId);
}

class Warn extends Command {
  final int staffId;
  const Warn(this.staffId);
}

class Promote extends Command {
  final int staffId;
  const Promote(this.staffId);
}

class Maintain extends Command {
  final int equipmentId;
  const Maintain(this.equipmentId);
}

class Repair extends Command {
  final int equipmentId;
  final String mode; // cheap | proper
  const Repair(this.equipmentId, this.mode);
}

class BuyEquipment extends Command {
  final String type;
  final bool secondHand;
  final int? replaceId;
  const BuyEquipment(this.type, {this.secondHand = false, this.replaceId});
}

class SellEquipment extends Command {
  final int equipmentId;
  const SellEquipment(this.equipmentId);
}

class ApplyLoan extends Command {
  final int amount, termWeeks;
  final bool secured;
  final String lender; // bank | private
  const ApplyLoan(this.amount, this.termWeeks,
      {this.secured = false, this.lender = 'bank'});
}

class AcceptCounterOffer extends Command {
  const AcceptCounterOffer();
}

class RepayLoan extends Command {
  final int loanId, amount;
  const RepayLoan(this.loanId, this.amount);
}

class StartCampaign extends Command {
  final String type;
  const StartCampaign(this.type);
}

class ReworkMenu extends Command {
  const ReworkMenu();
}

class SetParLevel extends Command {
  final String ingredientId;
  final int par;
  final String supplierId;
  const SetParLevel(this.ingredientId, this.par, this.supplierId);
}

class StartService extends Command {
  const StartService();
}

class OwnerQueueTask extends Command {
  final int taskId;
  const OwnerQueueTask(this.taskId);
}

class OwnerStand extends Command {
  final String? area; // door | tables | pass | dishes | null
  const OwnerStand(this.area);
}

class OwnerRush extends Command {
  final int groupId;
  const OwnerRush(this.groupId);
}

class OwnerTreat extends Command {
  final int groupId;
  const OwnerTreat(this.groupId);
}

class OwnerBringBill extends Command {
  final int groupId;
  const OwnerBringBill(this.groupId);
}

class MoveStaff extends Command {
  final int staffId;
  final String role;
  const MoveStaff(this.staffId, this.role);
}

class OwnerRest extends Command {
  final bool rest;
  const OwnerRest(this.rest);
}

class ResolveIncident extends Command {
  final int instanceId;
  final String optionId;
  const ResolveIncident(this.instanceId, this.optionId);
}

class PayPayable extends Command {
  final int payableId;
  const PayPayable(this.payableId);
}

class EndService extends Command {
  const EndService();
}

class EndDay extends Command {
  const EndDay();
}

class TakeLifeline extends Command {
  final String kind; // emergencyLoan | sellEquipment | investor
  final int? equipmentId;
  const TakeLifeline(this.kind, {this.equipmentId});
}

/// The player has read the morning notices.
class AckNotices extends Command {
  const AckNotices();
}

// ------------------------------------------------------------ Phase 2: the chain

/// Which outlet the player is looking at; commands act on it.
class SelectLocation extends Command {
  final int locationId;
  const SelectLocation(this.locationId);
}

/// Prep: choose where to start the day (free). Service: drive there (takes time and energy).
class OwnerTravel extends Command {
  final int locationId;
  const OwnerTravel(this.locationId);
}

class BuyOutlet extends Command {
  final int offerIndex;
  final String? themeId;
  const BuyOutlet(this.offerIndex, {this.themeId});
}

class InspectOutlet extends Command {
  final int offerIndex;
  const InspectOutlet(this.offerIndex);
}

class BuildOutlet extends Command {
  final int siteId;
  final String size; // small medium large
  final String fitOut; // basic standard premium
  final String? themeId;
  const BuildOutlet(this.siteId, this.size, this.fitOut, {this.themeId});
}

class HireManager extends Command {
  final int applicantId;
  const HireManager(this.applicantId);
}

class PromoteToManager extends Command {
  final int staffId;
  const PromoteToManager(this.staffId);
}

class TransferStaff extends Command {
  final int staffId, toLocationId;
  const TransferStaff(this.staffId, this.toLocationId);
}

class Renovate extends Command {
  final int tables;
  const Renovate(this.tables);
}

class SetPolicies extends Command {
  final int? spendingLimit, maintenanceThreshold;
  final String? stance;
  final bool? mayHire, mayGiveRaises, autoOrder;
  const SetPolicies(
      {this.spendingLimit,
      this.maintenanceThreshold,
      this.stance,
      this.mayHire,
      this.mayGiveRaises,
      this.autoOrder});
}

class SetManagerBonus extends Command {
  final int pct;
  const SetManagerBonus(this.pct);
}

class AnswerRequest extends Command {
  final int requestId;
  final String answer; // approve deny cheaper
  const AnswerRequest(this.requestId, this.answer);
}

class Audit extends Command {
  const Audit();
}

class ListOutlet extends Command {
  final bool list;
  const ListOutlet(this.list);
}

class AcceptSaleOffer extends Command {
  final int index;
  const AcceptSaleOffer(this.index);
}

class QuickSale extends Command {
  const QuickSale();
}

class CloseOutlet extends Command {
  const CloseOutlet();
}

class SetDelivery extends Command {
  final bool on;
  const SetDelivery(this.on);
}

class BuildCentralKitchen extends Command {
  const BuildCentralKitchen();
}

class SignBulkContract extends Command {
  const SignBulkContract();
}

// ------------------------------------------------------------ Phase 3: the group

class StartFranchise extends Command {
  const StartFranchise();
}

class EndGame extends Command {
  const EndGame();
}
