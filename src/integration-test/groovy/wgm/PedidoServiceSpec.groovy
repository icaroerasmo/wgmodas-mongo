package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class PedidoServiceSpec extends Specification {

    PedidoService pedidoService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new Pedido(...).save(flush: true, failOnError: true)
        //new Pedido(...).save(flush: true, failOnError: true)
        //Pedido pedido = new Pedido(...).save(flush: true, failOnError: true)
        //new Pedido(...).save(flush: true, failOnError: true)
        //new Pedido(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //pedido.id
    }

    void "test get"() {
        setupData()

        expect:
        pedidoService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<Pedido> pedidoList = pedidoService.list(max: 2, offset: 2)

        then:
        pedidoList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        pedidoService.count() == 5
    }

    void "test delete"() {
        Long pedidoId = setupData()

        expect:
        pedidoService.count() == 5

        when:
        pedidoService.delete(pedidoId)
        sessionFactory.currentSession.flush()

        then:
        pedidoService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        Pedido pedido = new Pedido()
        pedidoService.save(pedido)

        then:
        pedido.id != null
    }
}
