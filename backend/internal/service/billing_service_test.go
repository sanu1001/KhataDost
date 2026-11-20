package service

import (
	"reflect"
	"testing"

	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// khataEntriesFor is the khata rule of a customer's bill, kept in the
// service so the repository only writes what it is handed.
func TestKhataEntriesFor(t *testing.T) {
	credit := func(a float64) repository.KhataEntryInput {
		return repository.KhataEntryInput{Type: "credit", Amount: a, LinkToBill: true}
	}
	payment := func(a float64) repository.KhataEntryInput {
		return repository.KhataEntryInput{Type: "payment", Amount: a}
	}

	tests := []struct {
		name        string
		total, paid float64
		want        []repository.KhataEntryInput
	}{
		{"paid in full writes nothing", 250, 250, nil},
		{"within half a paisa counts as paid in full", 250, 250.004, nil},
		{"nothing paid is one credit", 250, 0, []repository.KhataEntryInput{credit(250)}},
		{"part paid is credit then payment", 500, 300, []repository.KhataEntryInput{credit(500), payment(300)}},
		{"overpay pays down old dues", 250, 300, []repository.KhataEntryInput{credit(250), payment(300)}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := khataEntriesFor(tc.total, tc.paid)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("khataEntriesFor(%v, %v) = %+v, want %+v", tc.total, tc.paid, got, tc.want)
			}
		})
	}
}
