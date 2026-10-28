import { Controller } from "@hotwired/stimulus"

// Records audio in the browser and puts it into the form's file input,
// so the normal form submit uploads it like a chosen file.
export default class extends Controller {
  static targets = ["consent", "startButton", "stopButton", "timer", "preview", "fileInput", "submitButton", "message"]
  static values = { maxSeconds: { type: Number, default: 300 } }

  connect() {
    this.isRecording = false
    this.updateStartButton()
  }

  // Release the microphone if the user navigates away mid-recording.
  disconnect() {
    clearInterval(this.timerInterval)
    this.stream?.getTracks().forEach((track) => track.stop())
  }

  updateStartButton() {
    this.startButtonTarget.disabled = !this.consentTarget.checked || this.isRecording
  }

  async start() {
    this.showMessage("")

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (error) {
      this.showMessage("Microphone access was blocked. Allow it in your browser settings, or choose a file below.")
      return
    }

    // Chrome and Firefox record webm, Safari records mp4. Let the browser pick what it supports.
    const mimeType = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"].find((type) => MediaRecorder.isTypeSupported(type))
    this.recorder = new MediaRecorder(this.stream, mimeType ? { mimeType } : {})
    this.chunks = []
    this.recorder.addEventListener("dataavailable", (event) => this.chunks.push(event.data))
    this.recorder.addEventListener("stop", () => this.saveRecording())
    this.recorder.start()

    this.isRecording = true
    this.startedAt = Date.now()
    this.timerTarget.textContent = "0:00"
    this.timerInterval = setInterval(() => this.tick(), 1000)
    this.toggleControls()
  }

  stop() {
    this.stopRecording()
  }

  // private

  tick() {
    const seconds = Math.floor((Date.now() - this.startedAt) / 1000)
    this.timerTarget.textContent = this.formatTime(seconds)

    if (seconds >= this.maxSecondsValue) {
      this.stopRecording()
      this.showMessage(`Recording stopped at the ${this.formatTime(this.maxSecondsValue)} limit.`)
    }
  }

  stopRecording() {
    clearInterval(this.timerInterval)
    if (this.recorder?.state === "recording") this.recorder.stop()
    this.stream?.getTracks().forEach((track) => track.stop())
    this.isRecording = false
    this.toggleControls()
  }

  saveRecording() {
    // "audio/webm;codecs=opus" -> "audio/webm"
    const type = this.recorder.mimeType.split(";")[0]
    const extension = type === "audio/mp4" ? "m4a" : "webm"
    const file = new File(this.chunks, `recording.${extension}`, { type })

    // A file input's files can't be set directly; DataTransfer builds a FileList for it.
    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(file)
    this.fileInputTarget.files = dataTransfer.files

    if (this.previewTarget.src) URL.revokeObjectURL(this.previewTarget.src)
    this.previewTarget.src = URL.createObjectURL(file)
    this.previewTarget.hidden = false
    this.showMessage("Recording ready. Listen to it, then upload.")
  }

  toggleControls() {
    this.updateStartButton()
    this.stopButtonTarget.disabled = !this.isRecording
    this.submitButtonTarget.disabled = this.isRecording
  }

  showMessage(text) {
    this.messageTarget.textContent = text
  }

  formatTime(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = String(totalSeconds % 60).padStart(2, "0")
    return `${minutes}:${seconds}`
  }
}
