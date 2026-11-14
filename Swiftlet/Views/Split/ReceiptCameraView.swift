//
//  ReceiptCameraView.swift
//  Swiftlet
//

import AVFoundation
import SwiftUI

struct ReceiptCameraView<Leading: View, Trailing: View>: View {
    let onCapture: (Data) -> Void
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @State private var camera = ReceiptCameraController()

    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Color.black
                if camera.isDenied {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill").font(.largeTitle)
                        Text("Camera access is off. Turn it on in Settings, or choose a photo instead.")
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                } else {
                    CameraPreview(session: camera.session)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                leading.frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    camera.capture { data in
                        if let data { onCapture(data) }
                    }
                } label: {
                    ZStack {
                        Circle().strokeBorder(Color.ds(.textPrimary), lineWidth: 4).frame(width: 74, height: 74)
                        Circle().fill(Color.ds(.textPrimary)).frame(width: 58, height: 58)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!camera.isReady)
                .opacity(camera.isReady ? 1 : 0.4)
                .accessibilityLabel("Take photo")

                trailing.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }
}

@Observable
final class ReceiptCameraController {
    @ObservationIgnored let session = AVCaptureSession()
    private(set) var isReady = false
    private(set) var isDenied = false

    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "swiftlet.receipt-camera")
    @ObservationIgnored private var isConfigured = false
    @ObservationIgnored private var captureDelegate: PhotoDelegate?

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            isDenied = true
            return
        }
        let session = session
        let output = output
        let needsConfiguration = !isConfigured
        isConfigured = true
        let ready = await withCheckedContinuation { continuation in
            queue.async {
                if needsConfiguration {
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    if let device = AVCaptureDevice.default(for: .video),
                       let input = try? AVCaptureDeviceInput(device: device),
                       session.canAddInput(input) {
                        session.addInput(input)
                    }
                    if session.canAddOutput(output) { session.addOutput(output) }
                    session.commitConfiguration()
                }
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: !session.inputs.isEmpty)
            }
        }
        isReady = ready
    }

    func stop() {
        let session = session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture(completion: @escaping (Data?) -> Void) {
        guard isReady else { return }
        isReady = false
        let delegate = PhotoDelegate { [weak self] data in
            self?.captureDelegate = nil
            completion(data)
        }
        captureDelegate = delegate
        let output = output
        queue.async {
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onFinish: (Data?) -> Void

    init(onFinish: @escaping (Data?) -> Void) {
        self.onFinish = onFinish
    }

    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error _: Error?) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async { self.onFinish(data) }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context _: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_: PreviewView, context _: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
