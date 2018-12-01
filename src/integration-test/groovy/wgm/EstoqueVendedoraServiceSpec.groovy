package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class EstoqueVendedoraServiceSpec extends Specification {

    EstoqueVendedoraService estoqueVendedoraService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new EstoqueVendedora(...).save(flush: true, failOnError: true)
        //new EstoqueVendedora(...).save(flush: true, failOnError: true)
        //EstoqueVendedora estoqueVendedora = new EstoqueVendedora(...).save(flush: true, failOnError: true)
        //new EstoqueVendedora(...).save(flush: true, failOnError: true)
        //new EstoqueVendedora(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //estoqueVendedora.id
    }

    void "test get"() {
        setupData()

        expect:
        estoqueVendedoraService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<EstoqueVendedora> estoqueVendedoraList = estoqueVendedoraService.list(max: 2, offset: 2)

        then:
        estoqueVendedoraList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        estoqueVendedoraService.count() == 5
    }

    void "test delete"() {
        Long estoqueVendedoraId = setupData()

        expect:
        estoqueVendedoraService.count() == 5

        when:
        estoqueVendedoraService.delete(estoqueVendedoraId)
        sessionFactory.currentSession.flush()

        then:
        estoqueVendedoraService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        EstoqueVendedora estoqueVendedora = new EstoqueVendedora()
        estoqueVendedoraService.save(estoqueVendedora)

        then:
        estoqueVendedora.id != null
    }
}
