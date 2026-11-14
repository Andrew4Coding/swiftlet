//
//  ReceiptCameraView.swift
//  Swiftlet
//

import AVFoundation
import SwiftUI

struct ReceiptCameraView: View {
    let onFinish: (Data?) -> Void

    @State private var camera = ReceiptCameraController()

    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isDenied {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                    Text("Camera access is off. Turn it on in Settings to take a photo of the bill.")
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(32)
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button {
                        onFinish(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .accessibilityLabel("Close camera")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                if !camera.isDenied {
                    Button {
                        camera.capture { onFinish($0) }
                    } label: {
                        ZStack {
                            Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                            Circle().fill(.white).frame(width: 62, height: 62)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.isReady)
                    .opacity(camera.isReady ? 1 : 0.5)
                    .accessibilityLabel("Take photo")
                    .padding(.bottom, 32)
                }
            }
        }
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
