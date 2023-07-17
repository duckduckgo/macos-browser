package uot

import (
	"sync"
)

// nat store inside udp address and outside packet buf mapping.
type nat struct {
	mutex sync.RWMutex
	m     map[string]chan []byte
}

func (n *nat) Get(key string) chan []byte {
	n.mutex.RLock()
	defer n.mutex.RUnlock()
	return n.m[key]
}

func (n *nat) Set(key string, buf chan []byte) {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	n.m[key] = buf
}

func (n *nat) Del(key string) chan []byte {
	n.mutex.Lock()
	defer n.mutex.Unlock()

	buf, ok := n.m[key]
	if ok {
		delete(n.m, key)
		return buf
	}
	return nil
}
