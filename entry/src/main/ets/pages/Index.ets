interface WatchEvent {
  name: string;
  source: string;
  payload: string;
  critical: boolean;
}

interface Complication {
  title: string;
  value: string;
  eventName: string;
  payload: string;
  critical: boolean;
}

@Entry
@Component
struct Index {
  @State private sectionIndex: number = 0;
  @State private steps: number = 6840;
  @State private heartRate: number = 116;
  @State private calories: number = 420;
  @State private parentalGuard: boolean = false;
  @State private gestureLock: boolean = false;
  @State private sosArmed: boolean = false;
  @State private nestedScrollMode: boolean = false;
  @State private goalNote: string = '';
  @State private circularDelta: number = 0;
  @State private status: string = 'Rotate the dial';
  @State private eventLog: string[] = [
    'callbacks ready',
    'keyboard avoid: resize caret',
    'bound gestures active'
  ];

  private readonly sections: string[] = ['Move', 'Pulse', 'Coach'];
  private readonly complications: Complication[] = [
    { title: 'Steps', value: '6.8k', eventName: 'goal.reached', payload: 'Move ring +4%', critical: false },
    { title: 'Pulse', value: '116', eventName: 'heart.zone', payload: 'Cardio zone', critical: false },
    { title: 'SOS', value: 'Hold', eventName: 'sos.swipe', payload: 'Emergency gesture', critical: true }
  ];

  private startAngle: number = 0;
  private lastAngle: number = 0;
  private activeTouch: boolean = false;

  private getProgress(): number {
    return Math.min(100, Math.round(this.steps / 100));
  }

  private getSectionLabel(): string {
    return this.sections[this.sectionIndex];
  }

  private getAngle(x: number, y: number): number {
    return Math.atan2(y - 170, x - 170) * 180 / Math.PI;
  }

  private normalizeDelta(delta: number): number {
    if (delta > 180) {
      return delta - 360;
    }
    if (delta < -180) {
      return delta + 360;
    }
    return delta;
  }

  private log(message: string): void {
    this.eventLog = [message, ...this.eventLog].slice(0, 5);
  }

  private dispatchChildTouch(children: Array<TouchTestInfo>): TouchResult {
    this.log(`dispatch: ${children.length} hit`);
    return { strategy: TouchTestStrategy.DEFAULT };
  }

  private interceptComplicationTouch(event: TouchEvent): HitTestMode {
    if (event.type === TouchType.Down && this.parentalGuard) {
      this.log('intercept: guard checks');
    }
    return HitTestMode.Default;
  }

  private judgeCircularGesture(gestureInfo: GestureInfo, event: BaseGestureEvent): GestureJudgeResult {
    if (this.gestureLock && gestureInfo.tag !== 'sos-long-press') {
      this.log('judge: monopoly reject');
      return GestureJudgeResult.REJECT;
    }

    if (gestureInfo.tag === 'dial-pan') {
      this.log('judge: circular pan');
    }
    return GestureJudgeResult.CONTINUE;
  }

  private judgeRecognizer(event: BaseGestureEvent, current: GestureRecognizer,
    recognizers: Array<GestureRecognizer>): GestureJudgeResult {
    if (this.nestedScrollMode && current.getTag() === 'dial-pan') {
      current.preventBegin();
      this.log(`block: nested ${recognizers.length}`);
      return GestureJudgeResult.REJECT;
    }

    if (this.gestureLock && current.getTag() !== 'sos-long-press') {
      this.log('recognizer: monopoly');
      return GestureJudgeResult.REJECT;
    }
    return GestureJudgeResult.CONTINUE;
  }

  private allowBuiltInParallel(current: GestureRecognizer, others: Array<GestureRecognizer>): GestureRecognizer {
    if (this.nestedScrollMode && others.length > 0) {
      this.log('parallel: inner scroll');
      return others[0];
    }
    return current;
  }

  private dispatchWatchEvent(event: WatchEvent): void {
    let nextEvent: WatchEvent = event;
    if (this.parentalGuard && event.critical) {
      nextEvent = {
        name: 'guard.intercepted',
        source: event.source,
        payload: 'Critical gesture blocked',
        critical: false
      };
      this.status = 'SOS blocked';
    } else if (this.parentalGuard && event.name === 'heart.zone') {
      nextEvent = {
        name: event.name,
        source: event.source,
        payload: 'Intensity capped',
        critical: false
      };
      this.status = 'Event softened';
    } else {
      this.status = nextEvent.payload;
    }

    if (nextEvent.name === 'goal.reached') {
      this.steps += 240;
      this.calories += 12;
    }
    if (nextEvent.name === 'heart.zone') {
      this.heartRate = this.heartRate >= 148 ? 104 : this.heartRate + 8;
    }
    if (nextEvent.name === 'sos.swipe') {
      this.sosArmed = true;
      this.gestureLock = true;
      this.status = 'SOS owns event';
    }

    this.log(`${nextEvent.source}: ${nextEvent.name}`);
  }

  private handleComplicationTap(item: Complication): void {
    if (this.gestureLock && !item.critical) {
      this.log('monopoly: tap ignored');
      return;
    }
    this.dispatchWatchEvent({
      name: item.eventName,
      source: item.title,
      payload: item.payload,
      critical: item.critical
    });
  }

  private releaseMonopoly(): void {
    this.gestureLock = false;
    this.sosArmed = false;
    this.status = 'Gestures released';
    this.log('monopoly released');
  }

  private rotateSection(delta: number): void {
    if (this.gestureLock) {
      this.log('monopoly: rotate ignored');
      return;
    }
    if (Math.abs(delta) < 24) {
      return;
    }

    const direction: number = delta > 0 ? 1 : -1;
    const nextIndex: number = (this.sectionIndex + direction + this.sections.length) % this.sections.length;
    this.sectionIndex = nextIndex;
    this.circularDelta = Math.round(delta);
    this.status = delta > 0 ? 'Clockwise nav' : 'Counter nav';
    this.log(`judge: ${this.getSectionLabel()}`);
  }

  private handleDialTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }

    const x: number = event.touches[0].x;
    const y: number = event.touches[0].y;
    const angle: number = this.getAngle(x, y);

    if (event.type === TouchType.Down) {
      this.activeTouch = true;
      this.startAngle = angle;
      this.lastAngle = angle;
      return;
    }

    if (!this.activeTouch) {
      return;
    }

    if (event.type === TouchType.Move) {
      const delta: number = this.normalizeDelta(angle - this.lastAngle);
      this.lastAngle = angle;
      this.rotateSection(delta);
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.activeTouch = false;
      const totalDelta: number = this.normalizeDelta(angle - this.startAngle);
      this.circularDelta = Math.round(totalDelta);
    }
  }

  @Builder
  private ComplicationButton(item: Complication) {
    Column({ space: 2 }) {
      Text(item.value)
        .fontSize(item.critical ? 10 : 13)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.critical ? '#FFE2E2' : '#FFFFFF')
        .maxLines(1)
      Text(item.title)
        .fontSize(8)
        .fontColor('#A6B6BC')
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .width(48)
    .height(31)
    .borderRadius(16)
    .backgroundColor(item.critical && this.sosArmed ? '#D63D36' : '#18313A')
    .id(item.critical ? 'sosComplication' : `${item.title.toLowerCase()}Complication`)
    .border({
      width: item.critical ? 2 : 1,
      color: item.critical ? '#FF766F' : '#2B5964'
    })
    .onClick(() => {
      this.handleComplicationTap(item);
    })
    .monopolizeEvents(item.critical && this.sosArmed)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 1 })
          .tag(`${item.title.toLowerCase()}-tap`)
          .onAction(() => {
            this.handleComplicationTap(item);
          }),
        LongPressGesture({ duration: 650 })
          .tag(item.critical ? 'sos-long-press' : `${item.title.toLowerCase()}-long-press`)
          .onAction(() => {
            this.dispatchWatchEvent({
              name: item.critical ? 'sos.swipe' : item.eventName,
              source: item.title,
              payload: item.critical ? 'Emergency gesture' : item.payload,
              critical: item.critical
            });
          })
      ),
      item.critical ? GestureMask.IgnoreInternal : GestureMask.Normal
    )
  }

  @Builder
  private MetricStrip() {
    Row({ space: 6 }) {
      this.MetricPill('Steps', `${this.steps}`, '#84DCC6')
      this.MetricPill('HR', `${this.heartRate}`, '#F26D6D')
      this.MetricPill('Cal', `${this.calories}`, '#FFD166')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  @Builder
  private MetricPill(label: string, value: string, color: string) {
    Column({ space: 1 }) {
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
      Text(label)
        .fontSize(9)
        .fontColor('#8EA1A8')
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .width(52)
    .height(30)
    .borderRadius(15)
    .backgroundColor('#10242B')
  }

  @Builder
  private EventLog() {
    Column({ space: 3 }) {
      ForEach(this.eventLog, (item: string) => {
        Text(item)
          .fontSize(8)
          .fontColor('#B8C7CC')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(142)
          .textAlign(TextAlign.Center)
      }, (item: string) => item)
    }
    .height(32)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Column({ space: 3 }) {
        Text('Fit Dial')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F6FAFB')
          .margin({ top: 8 })

        Text(this.status)
          .fontSize(9)
          .fontColor(this.gestureLock ? '#FF928B' : '#9FEEF0')
          .height(12)
          .maxLines(1)

        Stack() {
          Column({ space: 6 }) {
            Text(this.getSectionLabel())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(1)
            Text(`${this.getProgress()}% goal`)
              .fontSize(10)
              .fontColor('#84DCC6')
              .maxLines(1)
            Text(`turn ${this.circularDelta} deg`)
              .fontSize(8)
              .fontColor('#8EA1A8')
              .maxLines(1)
          }
          .justifyContent(FlexAlign.Center)
          .width(78)
          .height(78)
          .borderRadius(39)
          .backgroundColor('#0B1B21')
          .border({ width: 4, color: this.gestureLock ? '#E4574F' : '#2BC4B6' })
        }
        .width(92)
        .height(92)
        .borderRadius(46)
        .backgroundColor('#14323A')
        .onClick(() => {
          this.rotateSection(30);
        })
        .onTouch((event: TouchEvent) => {
          this.handleDialTouch(event);
        })
        .gesture(
          PanGesture({ direction: PanDirection.All, distance: 6 })
            .tag('dial-pan')
            .onActionStart(() => {
              this.log(this.nestedScrollMode ? 'block: inner wins' : 'block: dial wins');
            })
            .onActionUpdate((event: GestureEvent) => {
              if (!this.nestedScrollMode) {
                this.rotateSection(event.offsetX + event.offsetY);
              }
            })
        )
        .parallelGesture(
          RotationGesture()
            .tag('dial-rotation')
            .onActionUpdate((event: GestureEvent) => {
              this.rotateSection(event.angle);
            }),
          GestureMask.Normal
        )
        .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
          return this.judgeCircularGesture(gestureInfo, event);
        })
        .onGestureRecognizerJudgeBegin((event: BaseGestureEvent, current: GestureRecognizer,
          recognizers: Array<GestureRecognizer>) => {
          return this.judgeRecognizer(event, current, recognizers);
        })
        .shouldBuiltInRecognizerParallelWith((current: GestureRecognizer, others: Array<GestureRecognizer>) => {
          return this.allowBuiltInParallel(current, others);
        })

        if (this.sectionIndex === 2) {
          Column({ space: 3 }) {
            Text('Coach note')
              .fontSize(9)
              .fontColor('#9FEEF0')
              .height(12)
              .maxLines(1)

            Stack() {
              Text(this.goalNote.length > 0 ? this.goalNote : 'Tap to edit')
                .fontSize(11)
                .fontColor(this.goalNote.length > 0 ? '#FFFFFF' : '#8AA4AA')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
                .width(150)

              TextInput({ placeholder: '', text: this.goalNote })
                .fontSize(11)
                .fontColor('#FFFFFF')
                .caretColor('#9FEEF0')
                .height(30)
                .width(150)
                .borderRadius(15)
                .backgroundColor('#122930')
                .opacity(0.02)
                .enableKeyboardOnFocus(true)
                .onChange((value: string) => {
                  this.goalNote = value;
                  this.log('callback: note input');
                })
            }
            .width(158)
            .height(32)
            .borderRadius(16)
            .backgroundColor('#122930')
            .border({ width: 1, color: '#315963' })
          }
          .height(49)
          .justifyContent(FlexAlign.Center)
        } else {
          Row({ space: 7 }) {
            ForEach(this.complications, (item: Complication) => {
              this.ComplicationButton(item)
            }, (item: Complication) => item.title)
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 1 })
          .onChildTouchTest((children: Array<TouchTestInfo>) => {
            return this.dispatchChildTouch(children);
          })
          .onTouchIntercept((event: TouchEvent) => {
            return this.interceptComplicationTouch(event);
          })
        }

        Row({ space: 8 }) {
          Text(this.parentalGuard ? 'Guard' : 'Open')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(44)
            .height(22)
            .borderRadius(11)
            .backgroundColor(this.parentalGuard ? '#5E3CA7' : '#24434B')
            .onClick(() => {
              this.parentalGuard = !this.parentalGuard;
              this.log(this.parentalGuard ? 'intercept enabled' : 'intercept off');
            })
          Text(this.nestedScrollMode ? 'Inner' : 'Dial')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(44)
            .height(22)
            .borderRadius(11)
            .backgroundColor(this.nestedScrollMode ? '#406A57' : '#24434B')
            .onClick(() => {
              this.nestedScrollMode = !this.nestedScrollMode;
              this.log(this.nestedScrollMode ? 'nested scroll owns' : 'dial owns pan');
            })
          Text('Free')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(44)
            .height(22)
            .borderRadius(11)
            .backgroundColor('#24434B')
            .onClick(() => {
              this.releaseMonopoly();
            })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')

        if (this.sectionIndex !== 2) {
          Text(this.eventLog[0])
            .fontSize(8)
            .fontColor('#B8C7CC')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(142)
            .height(10)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#071016')
  }
}
