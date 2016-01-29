
all: IconOverlay

IconOverlay: IconOverlay.swift
	xcrun -sdk macosx swiftc $@.swift -o $@

