import 'models.dart';

/// What a roll's jobs add to its status: the steps still open ([open]; at
/// home when [atHome], else at a lab), or the steps done once it is back.
typedef RollStage = ({
  bool open,
  bool atHome,
  bool develop,
  bool scan,
  bool print,
});

/// The stage of [roll], or null when its plain status says it all (not
/// processed yet, or a summary without the job fields).
RollStage? rollStage(RollSummary roll) {
  switch (roll.status) {
    case RollStatus.atLab:
      final open = roll.openJobTypes;
      if (open == null || open.isEmpty) return null;
      return (
        open: true,
        atHome: _atHome(roll),
        develop: open.any((t) => t.developsFilm),
        scan: open.any((t) => t.hasScans),
        print: open.contains(ProcessingType.print),
      );
    case RollStatus.developed || RollStatus.scanned:
      final (developed, scanned) = (roll.developed, roll.scanned);
      if (developed == null || scanned == null) return null;
      if (!developed && !scanned) {
        // Every closed job was a print job; the server still says developed.
        return roll.status == RollStatus.developed
            ? (
                open: false,
                atHome: false,
                develop: false,
                scan: false,
                print: true,
              )
            : null;
      }
      return (
        open: false,
        atHome: false,
        develop: developed,
        scan: scanned,
        print: false,
      );
    default:
      return null;
  }
}

/// Status at_lab with no open job at a lab: processed at home. Null
/// [RollSummary.openAtLab] (older server) counts as at a lab.
bool _atHome(RollSummary roll) =>
    roll.status == RollStatus.atLab && roll.openAtLab == false;

/// Whether [roll] belongs under the [status] chip. A roll both developed and
/// scanned is under both chips; a roll processed at home is under none.
bool inStatusChip(RollSummary roll, RollStatus status) =>
    !_atHome(roll) &&
    switch (status) {
      RollStatus.developed => roll.developed ?? roll.status == status,
      RollStatus.scanned => roll.scanned ?? roll.status == status,
      _ => roll.status == status,
    };
